// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title CrowFunding
 * @dev A smart contract for creating and managing a crowdfunding campaign with multiple funding tiers.
 *      Supports goal-based funding, campaign state management, fund withdrawals, and refunds.
 */
contract CrowdFunding {
    
    /** @notice Name of the crowdfunding campaign */
    string public name;

    /** @notice Description of the crowdfunding campaign */
    string public description;

    /** @notice Goal amount of the crowdfunding campaign */
    uint256 public goal;

    /** @notice Deadline (timestamp) of the crowdfunding campaign */
    uint256 public deadline;

    /** @notice Owner/creator of the crowdfunding campaign */
    address public owner;

    /** @notice Indicates whether the campaign is paused */
    bool public paused;

    /**
     * @notice Enum representing the possible states of the campaign.
     * @dev Active - Campaign is ongoing and accepting contributions.
     *      Successful - Campaign has met its goal before the deadline.
     *      Failed - Campaign did not meet its goal before the deadline.
     */
    enum CampaignState {Active, Successful, Failed}

    /** @notice Current state of the campaign */
    CampaignState public state;

    /**
     * @notice Structure defining a funding tier in the campaign.
     * @param name Name of the funding tier.
     * @param amount Fixed amount required to participate in this tier.
     * @param backers Number of contributors in this tier.
     */
    struct Tier {
        string name;
        uint256 amount;
        uint256 backers;
    }

    /**
     * @notice Structure defining a backer (supporter) of the campaign.
     * @param totalContribution Total contribution made by the backer.
     * @param fundedTiers Mapping of tier index to funding status (true if funded).
     */
    struct Backer {
        uint256 totalContribution;
        mapping(uint256 => bool) fundedTiers;
    }

    /** @notice Mapping to track contributions of each backer */
    mapping(address => Backer) public backers;

    /** @notice List of available funding tiers */
    Tier[] public tiers;

    /** 
     * @dev Modifier to restrict function access to only the contract owner.
     *      Ensures only the campaign owner can perform certain actions.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner is authorized to perform this action");
        _;
    }

    /** 
     * @dev Modifier to ensure the campaign is still open for funding.
     */
    modifier campaignOpen() {
        require(state == CampaignState.Active, "Campaign is not open");
        _;
    }

    /** 
     * @dev Modifier to ensure that the campaign is not paused.
     */
    modifier notPaused() {
        require(!paused, "Campaign is paused.");
        _;
    }

    /**
     * @notice Initializes a new crowdfunding campaign.
     * @param _name Name of the campaign.
     * @param _description Description of the campaign.
     * @param _goal Funding goal in wei.
     * @param _durationInDays Campaign duration in days.
     */
    constructor(
        address _owner,
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) {
        name = _name;
        description = _description;
        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
        owner = _owner;
        state = CampaignState.Active;
    }

    /**
     * @notice Adds a new funding tier to the campaign.
     * @dev Only the owner can add tiers.
     * @param _name Name of the funding tier.
     * @param _amount Contribution amount required for this tier.
     */
    function addTier(string memory _name, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Amount must be greater than 0.");
        tiers.push(Tier(_name, _amount, 0));
    }

    /**
     * @notice Removes a funding tier from the campaign.
     * @dev Only the owner can remove tiers.
     * @param _index Index of the tier to remove.
     */
    function removeTier(uint256 _index) public onlyOwner {
        require(_index < tiers.length, "Tier does not exist");
        tiers[_index] = tiers[tiers.length - 1];
        tiers.pop();
    }

    /**
     * @dev Internal function to check and update the campaign state.
     *      Updates to "Successful" if the goal is met before the deadline,
     *      otherwise updates to "Failed" after the deadline.
     */
    function checkAndUpdateCampaignState() internal {
        if (state == CampaignState.Active) {
            if (block.timestamp >= deadline) {
                state = address(this).balance >= goal ? CampaignState.Successful : CampaignState.Failed;
            } else {
                state = address(this).balance >= goal ? CampaignState.Successful : CampaignState.Active;
            }
        }
    }

    /**
     * @notice Allows users to fund the campaign by selecting a funding tier.
     * @param _tierIndex Index of the selected tier.
     */
    function fund(uint256 _tierIndex) public payable campaignOpen notPaused {
        require(_tierIndex < tiers.length, "Invalid tier.");
        require(block.timestamp < deadline, "Campaign has ended.");
        require(msg.value > 0, "Contribution must be greater than 0.");

        uint256 requiredAmount = tiers[_tierIndex].amount;
        require(msg.value == requiredAmount,"Incorrect amount provided.");

        tiers[_tierIndex].backers++;
        backers[msg.sender].totalContribution += msg.value;
        backers[msg.sender].fundedTiers[_tierIndex] = true;
        checkAndUpdateCampaignState();
    }

    /**
     * @notice Allows the owner to withdraw funds if the campaign is successful.
     */
    function withdraw() public onlyOwner {
        checkAndUpdateCampaignState();
        require(state == CampaignState.Successful, "Campaign not successful.");
        require(address(this).balance >= goal, "Goal has not been reached");
        require(address(this).balance > 0, "No funds to withdraw.");

        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }

    /**
    * @notice Allows backers to claim a refund if the campaign fails.
    * @dev Clears the backer's contribution and funded tiers after refund.
    */
    function refund() public {
        checkAndUpdateCampaignState();
        require(state == CampaignState.Failed, "Refunds not available.");
        
        uint256 amount = backers[msg.sender].totalContribution;
        require(amount > 0, "No contribution to refund");

        // Reset backer's total contribution
        backers[msg.sender].totalContribution = 0;

        // Clear funded tiers for this backer
        for (uint256 i = 0; i < tiers.length; i++) {
            if (backers[msg.sender].fundedTiers[i]) {
                backers[msg.sender].fundedTiers[i] = false;
                tiers[i].backers--; // Reduce backer count for that tier
            }
        }

        // Send refund
        payable(msg.sender).transfer(amount);

        // Emit refund event
        emit RefundIssued(msg.sender, amount);
    }

    /** 
    * @notice Emitted when a backer is refunded.
    * @param backer Address of the refunded backer.
    * @param amount Amount refunded.
    */
    event RefundIssued(address indexed backer, uint256 amount);


    /**
     * @notice Checks if a backer has contributed to a specific tier.
     * @param _backer Address of the backer.
     * @param _tierIndex Index of the tier.
     * @return Boolean indicating if the backer has funded the tier.
     */
    function hasFundedTier(address _backer, uint256 _tierIndex) public view returns (bool) {
        return backers[_backer].fundedTiers[_tierIndex];
    }

    /**
     * @notice Returns the current balance of the campaign contract.
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns all available funding tiers.
     */
    function getTiers() public view returns (Tier[] memory) {
        return tiers;
    }

    /**
     * @notice Toggles the paused state of the campaign.
     */
    function togglePause() public onlyOwner {
        paused = !paused;
    }

    /**
     * @notice Returns the current state of the campaign.
     */
    function getCampaignStatus() public view returns (CampaignState) {
        if (state == CampaignState.Active && block.timestamp > deadline) {
            return address(this).balance >= goal ? CampaignState.Successful : CampaignState.Failed;
        }
        return state;
    }

    /**
     * @notice Allows the owner to extend the campaign deadline.
     * @param _daysToAdd Number of days to extend.
     */
    function extendDeadline(uint256 _daysToAdd) public onlyOwner campaignOpen {
        deadline += _daysToAdd * 1 days;
    }
}
