// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC721 {
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256);

    function ownerOf(uint256 id) external view returns (address);

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

contract MarketPlace is Initializable {
    event InstantBuy(
        address indexed from,
        address indexed to,
        uint256 price,
        uint256 indexed id
    );

    event Withdraw(address indexed receiver, uint256 val);
    event WithdrawBid(address indexed bidder, uint256 amount);
    event Bid(address indexed bidder, uint256 indexed nftId, uint256 bidAmount);
    event AssetClaimed(address indexed receiver, uint256 indexed nftId);

    event Start(address indexed owner, uint256 indexed id);
    event End(
        address indexed highestBidder,
        uint256 highestBid,
        uint256 indexed nftId
    );

    struct Auc {
        // uint256 nftId;
        address creator;
        // bool started;
        // bool ended;
        uint32 endAt;
        address highestBidder;
        // uint256 highestBid;
        uint256 startingBid;
        mapping(address => uint256) pendingReturns;
    }
    IERC721 public nftCollection;
    address public nftAddress;

    mapping(uint256 => Auc) public Auctions;

    mapping(address => uint256) public toPay;
    mapping(uint256 => uint256) public instantPrice;

    function initialize(address nftAddressCol) public initializer {
        nftCollection = IERC721(nftAddressCol);
        nftAddress = nftAddressCol;
    }

    function setPrice(uint256 _id, uint256 _price) external {
        address owner = nftCollection.ownerOf(_id);

        require(msg.sender == owner, "not owner");

        instantPrice[_id] = _price;
    }

    function instantBuy(uint256 _id) external payable {
        require(instantPrice[_id] > 0, "Not on sale");
        require(msg.value >= instantPrice[_id], "Not enough ether");
        require(
            nftCollection.getApproved(_id) == address(this) ||
                nftCollection.isApprovedForAll(
                    nftCollection.ownerOf(_id),
                    address(this)
                ),
            "not approved"
        );
        instantPrice[_id] = 0;

        address owner = nftCollection.ownerOf(_id);

        nftCollection.transferFrom(owner, msg.sender, _id);

        (address royalty, uint256 royaltyFees) = nftCollection.royaltyInfo(
            _id,
            msg.value
        );
        unchecked {
            if (royalty == owner) {
                toPay[royalty] += msg.value;
            } else {
                toPay[royalty] += royaltyFees;
                toPay[owner] += (msg.value - royaltyFees);
            }
        }
        emit InstantBuy(owner, msg.sender, msg.value, _id);
    }

    function withdrawEth() external {
        require(toPay[msg.sender] > 0, "we owe no money");
        uint256 val = toPay[msg.sender];
        toPay[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: val}("");
        require(success, "transaction failed");
        emit Withdraw(msg.sender, val);
    }

    function startAuction(
        uint256 _id,
        uint256 _starting,
        uint32 duration
    ) external {
        address owner = nftCollection.ownerOf(_id);
        require(msg.sender == owner, "Not owner");

        nftCollection.transferFrom(owner, address(this), _id);
        instantPrice[_id] = 0;
        unchecked {
            Auc storage auc = Auctions[_id];
            auc.creator = owner;
            auc.endAt = uint32(block.timestamp + duration);
            // auc.nftId = _id;
            auc.startingBid = _starting;
            // auc.ended = false;
            // auc.started = true;
            auc.highestBidder = owner;
        }

        emit Start(owner, _id);
    }

    // function started(uint256 _id) internal view returns (bool) {
    //     Auc storage auc = Auctions[_id];
    //     if (auc.endAt >= block.timestamp) {
    //         return true;
    //     }
    //     return false;
    // }

    function endAuction(uint256 _id) external {
        Auc storage auc = Auctions[_id];

        // require(auc.started, "Not started");
        // require(auc.ended == false, "End already");
        require(auc.endAt <= block.timestamp, "Time left");
        // auc.ended = true;
        if (auc.highestBidder != address(0)) {
            (address royalty, uint256 royaltyFees) = nftCollection.royaltyInfo(
                _id,
                auc.pendingReturns[auc.highestBidder]
            );
            uint256 val = auc.pendingReturns[auc.highestBidder] - royaltyFees;
            unchecked {
                if (auc.creator == royalty) {
                    toPay[royalty] += (val + royaltyFees);
                } else {
                    toPay[auc.creator] += val;
                    toPay[royalty] += royaltyFees;
                }
            }
        }

        emit End(auc.highestBidder, auc.pendingReturns[auc.highestBidder], _id);
    }

    function bid(uint256 _id) external payable {
        Auc storage auc = Auctions[_id];
        require(auc.endAt > block.timestamp, "Ended");
        // require(auc.started == true, "Not started");
        require(
            (auc.pendingReturns[msg.sender] + msg.value) >
                auc.pendingReturns[auc.highestBidder] &&
                (auc.pendingReturns[msg.sender] + msg.value) >= auc.startingBid,
            "Only higher than current bid"
        );
        unchecked {
            auc.pendingReturns[msg.sender] += msg.value;
        }
        // auc.highestBid = auc.pendingReturns[msg.sender];
        auc.highestBidder = msg.sender;
        emit Bid(msg.sender, _id, msg.value);
    }

    function withdrawBid(uint256 _id) external {
        Auc storage auc = Auctions[_id];

        address winner = auc.highestBidder;
        require(msg.sender != winner, "Winner cannot withdraw");

        uint256 bal = auc.pendingReturns[msg.sender];
        require(bal > 0, "Not a bidder");
        auc.pendingReturns[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bal}("");
        require(success, "transaction failed");
        emit WithdrawBid(msg.sender, bal);
    }

    function claimAsset(uint256 _id) external {
        Auc storage auc = Auctions[_id];
        require(auc.endAt <= block.timestamp, "not ended");
        address winner = auc.highestBidder;

        require(winner != address(0), "WINNER_ZERO");

        nftCollection.transferFrom(address(this), winner, _id);
        emit AssetClaimed(winner, _id);
    }

    function cancelAuction(uint256 _id) external {
        Auc storage auc = Auctions[_id];
        require(msg.sender == auc.creator, "Not allowed");

        // auc.ended = true;
        // auc.highestBid = 0;
        auc.endAt = uint32(block.timestamp - 1);
        auc.highestBidder = address(0);

        nftCollection.transferFrom(address(this), auc.creator, _id);
    }

    //Only for testing , not to be included in actual contract
    function endAuc(uint256 _id) external {
        Auc storage auc = Auctions[_id];
        auc.endAt = uint32(block.timestamp - 1);
    }
}
