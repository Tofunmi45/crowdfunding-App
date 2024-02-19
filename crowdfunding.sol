// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// our contract will be interacting with an ERC20 token
interface IERC20 {
    function transfer(address, uint) external returns (bool); 
    function transferFrom(address, address, uint) external returns (bool);
}

 // creating our crowdfunding contract properly
contract CrowdFund {
// Launch is the name of project.
    event Launch(
// ID is used to record the number of campaigns or identifier 
        uint id,
// the creators address (wallet or contract address)
        address indexed creator,
// goal is the target amount for the project Launch using the data type UINT
        uint goal,
// The time as at when the campaign for the project should start
        uint32 startAt,
// The time as at when the campaign for the project should end
        uint32 endAt
    );
// event to cancel a campaign with an id for the project 
    event Cancel(uint id);
// event pledge is the money the donor has given out already, it contains the id, the donors address
// and the amount the donor has donated
    event Pledge(uint indexed id, address indexed caller, uint amount);
// event unpledge is when you request your already donated fund.
    event Unpledge(uint indexed id, address indexed caller, uint amount);
//event claim is that the donations of a particular id has been claimed by the creator.
    event Claim(uint id);
//event refund comes after unpledge as the reversal of the fund will be made
    event Refund(uint id, address indexed caller, uint amount);
 
 //struct stores in data, thus this details below is being stored in the struct named Campaign.
    struct Campaign {

        // Creator of campaign

        address creator;

        // Amount of tokens to raise

        uint goal;

        // Total amount pledged

        uint pledged;

        // Timestamp of start of campaign

        uint32 startAt;

        // Timestamp of end of campaign

        uint32 endAt;

        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }
 
 //this term implies that the token cannot be changed
    IERC20 public immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns as the count is to increase by 1.
    uint public count;
    // Mapping from id to Campaign where id is the key and Campaign is the value
    mapping(uint => Campaign) public campaigns;

//the nested mapping named pledgedAmount is a Mapping from campaign id => pledger => amount pledged
    mapping(uint => mapping(address => uint)) public pledgedAmount;

//the constructor declares that all our tokens is ERC20 token that is called once.
    constructor(address _token) {
        token = IERC20(_token);
    }
 //function Launch to take in the goal, start time and end time of the campagin
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {

//require statement ensures that the time the campaign should start using block.timestamp
        require(_startAt >= block.timestamp, "start at < now");
//require statement ensures that the time the campaign should end.
        require(_endAt >= _startAt, "end at < start at");
//require statement ensure that the time duration we want the contract to accept funds 
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");
 //since we declared a state variable count, for every campaign, the count increases by 1
        count += 1;
//the details to be stored in the array of struct
        campaigns[count] = Campaign({
//the address of the creator for the fundraising project
            creator: msg.sender,
//the target amount of the project
            goal: _goal,
//the initial amount is zero
            pledged: 0,
// when the campaigns starts
            startAt: _startAt,
//when the campaign ends.
            endAt: _endAt,
//by default this is false because no payment or fund has been sent yet.
            claimed: false
        });
//Emit let the front end users see the when the project will start and end, 
//also the target amount of project
        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }
 //as declared in line 26 we declared a Canceled event using id, so we are creating the 
 //function to cancel the project as at when needed.
    function cancel(uint _id) external {
//this line of code is capturing the id of the campaign you want to cancel through 
//the mapping in line 73 saving up the data in 'Campaign'
        Campaign memory campaignStruct = campaigns[_id];
//require that the owner of the project is the msg.sender or the creator
//as only the creator can cancel a particular campaign
        require(campaignStruct.creator == msg.sender, "you are not the creator");
//require that once a campaign is running it cannot be canceled, else it displays started
        require(block.timestamp < campaignStruct.startAt, "started");
 //statement delete is used to delete or remove an array using the mapping campaigns through the id.
        delete campaigns[_id];
//emit is to display cancel at the users end. 
        emit Cancel(_id);
    }
//function pledge transfers money into the campaign, taking the input of id and amount you want to domate
    function pledge(uint _id, uint _amount) external {
//this line of code is capturing the id of the campaign you want to store through 
//the mapping in line 73 saving up the data in a variable'campaignStruct5'
//giving us access to the struct
        Campaign storage campaignStruct = campaigns[_id];
//require statement to check if the campaign has started or not, which has started. 
        require(block.timestamp >= campaignStruct.startAt, "not started");
//require statment to check if the campaign has not ended i.e it is lower than when the campaign will end.
        require(block.timestamp <= campaignStruct.endAt, "ended");
// records the amount we have in the goal for the campaign
        campaignStruct.goal += _amount;
//records the pledged amount to the campaign 
        campaignStruct.pledged += _amount;
//the amount the donor is donating with the address and a unique id.
        pledgedAmount[_id][msg.sender] += _amount;
//the transferFrom is coming from the msg.sender to the address and the amount used in transferring.
        token.transferFrom(msg.sender, address(this), _amount);
 //let the users see the display of the pledge statement.
        emit Pledge(_id, msg.sender, _amount);
    }
 //function unpledge takes the id and amount the donor included
    function unpledge(uint _id, uint _amount) external {

//this line of code is capturing the id of the campaign you want to store through 
//the mapping in line 73 saving up the data in a variable'campaignStruct5'
//giving us access to the struct
        Campaign storage campaignStruct = campaigns[_id];
//require stores the time the donor ended the campaign by unpledging the amount
        require(block.timestamp <= campaignStruct.endAt, "ended");
 //the code records the amount that was deducted 
        campaignStruct.pledged -= _amount;
//the code records the deduction done from the nested mapping
        pledgedAmount[_id][msg.sender] -= _amount;
// the code keeps the address of the donor and the amount deducted
        token.transfer(msg.sender, _amount);
 // emit displays the unique identifier, addres and amount that was unpledged to the front end user
        emit Unpledge(_id, msg.sender, _amount);
    }
 //function claim approves the unique id of the donor
    function claim(uint _id) external {

//this line of code is capturing the id of the campaign you want to store through 
//the mapping in line 73 saving up the data in a variable'campaignStruct5'
//giving us access to the struct
        Campaign storage campaignStruct = campaigns[_id];
//the statment records the owners as the creator in the variable campaignStruct
        require(campaignStruct.creator == msg.sender, "not creator");
//the statement records when the transaction ends and records in the variable.
        require(block.timestamp > campaignStruct.endAt, "not ended");
//the statement records the amount pledged which is lesser than the goal or target amount
        require(campaignStruct.pledged >= campaignStruct.goal, "pledged < goal");
//records the action is claimed
        require(!campaignStruct.claimed, "claimed");
 // the variable stores it as true 
        campaignStruct.claimed = true;
//the statement keeps the address of the creator, and the amount pledged.
        token.transfer(campaignStruct.creator, campaignStruct.pledged);
 // the statement displays the campaign id that was claimed
        emit Claim(_id);
    }
 //function to refund the pledge or amount using the id
    function refund(uint _id) external {
//this line of code is capturing the id of the campaign you want to cancel through 
//the mapping in line 73 saving up the data in 'campaignStruct'
        Campaign memory campaignStruct = campaigns[_id];
//statement to show that the transaction at that time did not end
        require(block.timestamp > campaignStruct.endAt, "not ended");
//statement to show that the pledged amount was removed or deducted from the goal
        require(campaignStruct.pledged < campaignStruct.goal, "pledged >= goal");
 // balance of nested mapping, the unique id and the address of where the money is going to
        uint bal = pledgedAmount[_id][msg.sender];
//amount of the pleedgedamount is equal to zero.
        pledgedAmount[_id][msg.sender] = 0;
//transfer of the fund to the address of the unpledged account.
        token.transfer(msg.sender, bal);
 //display the refund section to the front end users to take in the id, address and balance
        emit Refund(_id, msg.sender, bal);
    }

}
