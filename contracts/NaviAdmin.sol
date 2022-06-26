//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./OpenNaviPFP.sol";

contract ONAdmin is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _projectIds;
}

function _createProject (uint256 projectId)  
                   public {
        
        OpenNaviPFP public opennaviproject;
        opennaviproject = new OpenNaviPFP (baseUri);
        _projectIds.increment();
}
