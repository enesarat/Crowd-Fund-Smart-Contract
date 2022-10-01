// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// We can use external file call to import interface. I used the openzeppelin's ERC20 and IERC20 files.
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract CrowdFund{

    struct Campaign{        // We use struct as data structure to hold our Campaign data.
        address creator;     // Property to hold creator of campaign.
        uint goal;           // Property to hold the amount of tokens to raise of campaign.
        uint pledged;        // Property to hold total amount of pledged.
        uint32 startAt;      // Property to hold timestamp of start.
        uint32 endAt;        // Property to hold timestamp of end.
        bool claimed;        // Property to hold goal status of campaign.
    }

    // For minimizing the risk we only support one token per contract we will store the token in erc20. 
    IERC20 public immutable token; // We define variable as immutable to make sure  token will not be change.

    mapping(uint => Campaign) public campaigns; // We store campaign information according to the campaign id using mapping.
    mapping(uint => mapping(address => uint)) public pledgedAmount; // We store pledged amount according to the user which pledged any campaign using mapping.
    uint public count; // We store the campaign amount to use on launching campaign.

    // Initializes the token variable of the contract.
    constructor(address _token){
        token = IERC20(_token);
    } 

    event Launch(   // We defined the Launch event to monitor the status of launch functions in the background and be informed through variables.
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(   // We defined the Cancel event to monitor the status of cancel functions in the background and be informed through variables.
        uint id
    );
    event Pledge(   // We defined the Pledge event to monitor the status of pledge functions in the background and be informed through variables.
        uint indexed id,
        address indexed caller,
        uint amount
    );
    event Unpledge(   // We defined the Unpledge event to monitor the status of unpledge functions in the background and be informed through variables.
        uint indexed id,
        address indexed caller,
        uint amount
    );
    event Claim(   // We defined the Claim event to monitor the status of claim functions in the background and be informed through variables.
        uint id
    );
    event Refund(   // We defined the Refund event to monitor the status of refund functions in the background and be informed through variables.
        uint indexed id,
        address indexed caller,
        uint amount
    );


    // Users will be able to launch a campaign stating their goal that will be the amount of tokens that they want to raise the time when the campaign will start and the time when the campaign will end.
    function lunch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        require(_startAt >= block.timestamp, "start at < now");  // We check the start time of campaign. Because, start time must be greater than now to launch campaign.
        require(_startAt <= _endAt, "start at < now");  // We check the start time of campaign. Because, start time must be less than end time to launch campaign.
        require(_endAt <= block.timestamp + 90 days, "start at < now");  // We check the end time of campaign. Because, end time must be less than oe qrual to more 90 days from now to launch campaign.

        count += 1; // We increase the amount of campaign to use in launch process.
        campaigns[count] = Campaign({   // We transfer the campaign information to be launched over the current campaign amount to Campaigns mapping with a struct.
            creator: msg.sender,   // The person who invoked the launch function
            pledged: 0,  // Defaultly 0
            goal: _goal,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false  // Defaultly false. It will be true if the campaign reaches its goal.
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt); // Here we use the launch event we created earlier to be aware of the status.
    }

    // The campaign creator will be able to cancel campaign if the campaign has not yet started.
    function cancel(uint campaignId) external {
        Campaign memory campaign = campaigns[campaignId]; // We create campaign variable on storage to hold campaign informations which exist with given campaignId
        require(msg.sender == campaign.creator, "You must be creator to perform this operation.");  // We check the creator of campaign. Because, function caller must be same user to cancel campaign.
        require(block.timestamp < campaign.startAt, "Campaign already started!");  // We check the start time of campaign. Because, start time must be greater than now to cancel campaign.
        delete campaigns[campaignId];  // If the conditions are met, we delete the target campaign from mapping.

        emit Cancel(campaignId); // Here we use the cancel event we created earlier to be aware of the status.
    }

    // Users will be able to pledge while the campaign is still going. Fund Addition
    function pledge(uint campaignId, uint amount) external {
        Campaign storage campaign = campaigns[campaignId]; // We create campaign variable on storage to hold campaign informations which exist with given campaignId
        require(campaign.startAt <= block.timestamp, "Campaign not started!");  // We check the start time of campaign. Because, start time must be less than now to make pledge.
        require(campaign.endAt >= block.timestamp, "Campaign already ended!");  // We check the end time of campaign. Because, end time must be greater than now to make pledge.
        campaign.pledged += amount;  // If the conditions are met, we make pledge into the campaign.

        pledgedAmount[campaignId][msg.sender] += amount;  // We increase the pledged amount of the target campaign according to the function caller.
        token.transferFrom(msg.sender, address(this), amount);  // We transfer pledge amount from caller to campaign address over the token.

        emit Pledge(campaignId, msg.sender, amount); // Here we use the pledge event we created earlier to be aware of the status.
    }

    // Users will be able to unpledge while the campaign is still going. Fund Extraction
    function unpledge(uint campaignId, uint unpledgeAmount) external {
        Campaign storage campaign = campaigns[campaignId]; // We create campaign variable on storage to hold campaign informations which exist with given campaignId
        require(campaign.endAt >= block.timestamp, "Campaign already ended!");  // We check the end time of campaign. Because, end time must be greater than now to make unpledge.

        campaign.pledged -= unpledgeAmount;  // If the conditions are met, we make unpledge from the campaign.
        pledgedAmount[campaignId][msg.sender] -= unpledgeAmount;  // We decrease the unpledged amount of the target campaign according to the function caller.
        token.transfer(msg.sender, unpledgeAmount);  // We transfer unpledge amount to caller over the token.

        emit Unpledge(campaignId, msg.sender, unpledgeAmount);  // Here we use the unpledge event we created earlier to be aware of the status.
    }

    // If certain conditions are met, campaign creator will be able to claim all of the tokens that were pledged.
    function claim(uint campaignId) external {
        Campaign storage campaign = campaigns[campaignId];  // We create campaign variable on storage to hold campaign informations which exist with given campaignId
        require(campaign.creator == msg.sender, "You must be creator to perform this operation.");  // We check the creator of campaign. Because, function caller must be same user to cancel campaign.
        require(!campaign.claimed, "The campaign already claimed!");  // We check the claim status of campaign. Because, claim status must be false to claim campaign.
        require(campaign.endAt < block.timestamp, "The campaign is not over yet!");  // We check the end time of campaign. Because, end time must be less than now to claim campaign.
        require(campaign.pledged >= campaign.goal, "Target not reached!");  // We check the pledged amount of campaign. Because, pledged amount must be greater than campaign goal to claim campaign.

        campaign.claimed = true;  // If the conditions are met, we toggle claim status to true.
        token.transfer(msg.sender,campaign.pledged);  // accessingmessage.sender is cheaper on gas than accessing the state variable campaign.creator.  // We transfer pledge amount of campaign to campaign creator over the token.
        
        emit Claim(campaignId);  // Here we use the claim event we created earlier to be aware of the status.
    }

    // If campaign was unsuccessful then users will be able to call the function refund to get their tokens back.
    function refund(uint campaignId) external {
        Campaign storage campaign = campaigns[campaignId]; // We create campaign variable on storage to hold campaign informations which exist with given campaignId
        require(campaign.endAt < block.timestamp, "The campaign is not over yet!");  // We check the end time of campaign. Because, end time must be less than now to refund campaign.
        require(campaign.pledged < campaign.goal, "The campaign has reached its goal!");  // We check the pledged amount of campaign. Because, pledged amount must be less than campaign goal to refund campaign.

        uint balance = pledgedAmount[campaignId][msg.sender];  // If the conditions are met, we get the pledged amount of the target campaign according to the function caller into balance variable.
        pledgedAmount[campaignId][msg.sender] = 0;   // We assign zero to the pledged amount of the target campaign according to the function caller.
        token.transfer(msg.sender, balance);  // We transfer back pledged balance amount to caller over the token.

        emit Refund(campaignId, msg.sender, balance);  // Here we use the refund event we created earlier to be aware of the status.  
    }


}