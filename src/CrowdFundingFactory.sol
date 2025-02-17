// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CrowdFunding} from "./CrowdFunding.sol";

/**
 * @title CrowdFundingFactory
 * @dev Factory contract for deploying and managing multiple crowdfunding campaigns.
 *      Allows users to create campaigns and track their created campaigns.
 */
contract CrowdFundingFactory {

    /** @notice Address of the factory owner */
    address public owner;

    /** @notice Boolean indicating whether the factory is paused */
    bool public paused;

    /** 
     * @notice Struct representing a crowdfunding campaign.
     * @param owner Address of the campaign creator.
     * @param campaignAddress The deployed contract address of the campaign.
     * @param name Name of the campaign.
     * @param creationTime Timestamp of when the campaign was created.
     */
    struct Campaign {
        address owner;
        address campaignAddress;
        string name;
        uint256 creationTime;
    }

    /** @notice Array containing all deployed campaigns */
    Campaign[] public campaigns;

    /** @notice Mapping of user addresses to their created campaigns */
    mapping (address => Campaign[]) public userCampaigns;

    /** 
     * @dev Modifier to restrict function access to only the factory owner.
     */
    modifier onlyOwner(){
        require(msg.sender == owner, "Not the owner.");
        _;
    }

    /** 
     * @dev Modifier to ensure actions can only be performed when the factory is not paused.
     */
    modifier notPaused(){
        require(!paused, "Factory is paused.");
        _;
    }

    /**
     * @notice Constructor that sets the initial owner of the factory.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Creates a new crowdfunding campaign.
     * @dev Deploys a new instance of the `CrowdFunding` contract.
     * @param _name Name of the campaign.
     * @param _description Description of the campaign.
     * @param _goal Fundraising goal in wei.
     * @param _durationInDays Duration of the campaign in days.
     */
    function createCampaign(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external notPaused {
        // Deploy a new crowdfunding campaign contract
        CrowdFunding newCampaign = new CrowdFunding(
            msg.sender,
            _name,
            _description,
            _goal,
            _durationInDays
        );

        // Store the campaign details
        Campaign memory campaign = Campaign({
            campaignAddress : address(newCampaign),
            owner : msg.sender,
            name : _name,
            creationTime : block.timestamp
        });

        // Add the campaign to the global and user-specific campaign lists
        campaigns.push(campaign);
        userCampaigns[msg.sender].push(campaign);
    }

    /**
     * @notice Retrieves all campaigns created by a specific user.
     * @param _user Address of the user.
     * @return An array of Campaign structs representing the user's campaigns.
     */
    function getUserCampaigns(address _user) external view returns (Campaign[] memory) {
        return userCampaigns[_user];
    }

    /**
     * @notice Retrieves all campaigns deployed by the factory.
     * @return An array of Campaign structs representing all campaigns.
     */
    function getAllCampaigns() external view returns (Campaign[] memory) {
        return campaigns;
    }

    /**
     * @notice Toggles the paused state of the factory.
     * @dev When paused, new campaigns cannot be created.
     */
    function togglePause() public onlyOwner {
        paused = !paused;
    }
}
