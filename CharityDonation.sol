// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Charity Donation
 * @dev Implements donation process with anonimity.
 */

import "./IERC20.sol";

contract CharityDonation {
    event Begin(uint campaignId, address indexed creator, uint target, uint32 startDate, uint32 endDate);
    event Cancel(uint campaignId);
    event Offer(uint indexed campaignId, address indexed executer, uint amount);
    event Refuse(uint indexed campaignId, address indexed executer, uint amount);
    event Claim(uint campaignId);
    event Refund(uint campaignId, address indexed executer, uint amount);

    struct Campaign {
        address creator;
        uint target;
        uint offerd;
        uint32 startDate;
        uint32 endDate;
        bool claimed;
    }

    IERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate campaignId for new campaigns.
    uint public count;
    // Mapping from campaignId to Campaign
    mapping(uint => Campaign) public campaigns;
    // Mapping from campaign campaignId => Offerr => amount Offerd
    mapping(uint => mapping(address => uint)) public offerdAmount;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function begin(uint _target, uint32 _startDate, uint32 _endDate) external {
        require(_startDate >= block.timestamp, "Start date is less than current date!");
        require(_endDate >= _startDate, "End date is less than start date!");
        require(_endDate <= block.timestamp + 90 days, "End date is greater than maximum duration!");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            target: _target,
            offerd: 0,
            startDate: _startDate,
            endDate: _endDate,
            claimed: false
        });

        emit Begin(count, msg.sender, _target, _startDate, _endDate);
    }

    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "Sender is not the creator!");
        require(block.timestamp < campaign.startDate, "Campaign already started!");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    function offer(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startDate, "Campaign has not started yet!");
        require(block.timestamp <= campaign.endDate, "Campaign ended already!");

        campaign.offerd += _amount;
        offerdAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Offer(_id, msg.sender, _amount);
    }

    function refuse(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endDate, "Campaign ended already!");

        campaign.offerd -= _amount;
        offerdAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Refuse(_id, msg.sender, _amount);
    }

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "Sender is not the creator!");
        require(block.timestamp > campaign.endDate, "Campaign has not ended yet!");
        require(!campaign.claimed, "Donation is already claimed!");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.offerd);

        emit Claim(_id);
    }

    function refund(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endDate, "Campaign has not ended yet!");
        uint bal = offerdAmount[_id][msg.sender];
        offerdAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
