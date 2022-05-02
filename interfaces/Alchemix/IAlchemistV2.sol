pragma solidity >=0.8.4;

import "./alchemist/IAlchemistV2Actions.sol";
import "./alchemist/IAlchemistV2AdminActions.sol";
import "./alchemist/IAlchemistV2Errors.sol";
import "./alchemist/IAlchemistV2Immutables.sol";
import "./alchemist/IAlchemistV2Events.sol";
import "./alchemist/IAlchemistV2State.sol";

/// @title  IAlchemistV2
/// @author Alchemix Finance
interface IAlchemistV2 is
    IAlchemistV2Actions,
    IAlchemistV2AdminActions,
    IAlchemistV2Errors,
    IAlchemistV2Immutables,
    IAlchemistV2Events,
    IAlchemistV2State
{ }
