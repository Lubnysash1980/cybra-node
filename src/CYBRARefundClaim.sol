// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CYBRARefundClaim {

    enum Status {
        PENDING,
        EVIDENCE_RECORDED,
        CONFIRMED,
        REFUND_AUTHORIZED,
        REFUNDED
    }

    struct Claim {
        uint256 id;
        address merchant;
        uint256 amount;
        bytes32 orderHash;
        bytes32 paymentEvidenceHash;
        bytes32 nonDeliveryEvidenceHash;
        bytes32 identityEvidenceHash;
        uint8 requiredConfirmations;
        uint8 confirmations;
        Status status;
        bool refundExecuted;
    }

    address public owner;
    uint256 private _nextId;

    mapping(uint256 => Claim) private _claims;
    mapping(uint256 => bool) public claimExists;
    mapping(uint256 => address) public claimantOf;
    mapping(address => bool) public verifiers;
    mapping(uint256 => mapping(address => bool)) public confirmedBy;

    event ClaimCreated(uint256 indexed id, address indexed claimant, address indexed merchant, uint256 amount, bytes32 orderHash);
    event EvidenceRecorded(uint256 indexed id, bytes32 paymentHash, bytes32 nonDeliveryHash, bytes32 identityHash);
    event ClaimConfirmed(uint256 indexed id, address indexed confirmer, uint8 confirmations);
    event RefundAuthorized(uint256 indexed id, address indexed authorizer);
    event RefundRecorded(uint256 indexed id, address indexed merchant, uint256 amount);
    event VerifierSet(address indexed verifier, bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyAuthorized(uint256 id) {
        require(claimExists[id], "claim not found");
        require(
            msg.sender == claimantOf[id] ||
            verifiers[msg.sender] ||
            msg.sender == owner,
            "not authorized"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setVerifier(address v, bool status) external onlyOwner {
        require(v != address(0), "verifier=0");
        verifiers[v] = status;
        emit VerifierSet(v, status);
    }

    function createClaim(
        address merchant_,
        uint256 amount_,
        bytes32 orderHash_,
        uint8 requiredConfirmations_
    ) external returns (uint256) {
        require(merchant_ != address(0), "merchant=0");
        require(amount_ > 0, "amount=0");
        require(requiredConfirmations_ >= 2, "minimum two confirmations");
        require(orderHash_ != bytes32(0), "orderHash=0");

        uint256 id = _nextId++;
        Claim storage c = _claims[id];
        c.id = id;
        claimExists[id] = true;
        c.merchant = merchant_;
        c.amount = amount_;
        c.orderHash = orderHash_;
        c.requiredConfirmations = requiredConfirmations_;
        c.status = Status.PENDING;
        claimantOf[id] = msg.sender;

        emit ClaimCreated(id, msg.sender, merchant_, amount_, orderHash_);
        return id;
    }

    /// @notice Stores evidence hashes only; it does not validate off-chain evidence.
    function recordEvidence(
        uint256 id,
        bytes32 paymentHash,
        bytes32 nonDeliveryHash,
        bytes32 identityHash
    ) external onlyAuthorized(id) {
        Claim storage c = _claims[id];
        require(c.status == Status.PENDING, "evidence already recorded");
        require(paymentHash != bytes32(0), "paymentHash=0");
        require(nonDeliveryHash != bytes32(0), "nonDeliveryHash=0");
        require(identityHash != bytes32(0), "identityHash=0");
        c.paymentEvidenceHash = paymentHash;
        c.nonDeliveryEvidenceHash = nonDeliveryHash;
        c.identityEvidenceHash = identityHash;
        c.status = Status.EVIDENCE_RECORDED;
        emit EvidenceRecorded(id, paymentHash, nonDeliveryHash, identityHash);
    }

    function confirmClaim(uint256 id) external {
        require(claimExists[id], "claim not found");
        Claim storage c = _claims[id];
        require(verifiers[msg.sender], "only verifier");
        require(msg.sender != claimantOf[id], "claimant cannot verify");
        require(msg.sender != c.merchant, "merchant cannot verify");
        require(c.status == Status.EVIDENCE_RECORDED, "evidence required");
        require(!confirmedBy[id][msg.sender], "already confirmed");
        confirmedBy[id][msg.sender] = true;
        c.confirmations += 1;
        if (c.confirmations >= c.requiredConfirmations) {
            c.status = Status.CONFIRMED;
        }
        emit ClaimConfirmed(id, msg.sender, c.confirmations);
    }

    function isTRUE100(uint256 id) public view returns (bool) {
        if (!claimExists[id]) return false;
        Claim storage c = _claims[id];
        return c.requiredConfirmations > 0 &&
               c.confirmations >= c.requiredConfirmations;
    }

    function authorizeRefund(uint256 id) external onlyOwner {
        require(claimExists[id], "claim not found");
        Claim storage c = _claims[id];
        require(isTRUE100(id), "TRUE100 not reached");
        require(c.status == Status.CONFIRMED, "not CONFIRMED");
        c.status = Status.REFUND_AUTHORIZED;
        emit RefundAuthorized(id, msg.sender);
    }

    /// @notice Records an externally completed refund; this function does not transfer funds.
    function markRefunded(uint256 id) external onlyOwner {
        require(claimExists[id], "claim not found");
        Claim storage c = _claims[id];
        require(c.status == Status.REFUND_AUTHORIZED, "not authorized");
        require(!c.refundExecuted, "already refunded");
        c.refundExecuted = true;
        c.status = Status.REFUNDED;
        emit RefundRecorded(id, c.merchant, c.amount);
    }

    function claims(uint256 id) external view returns (
        uint256,
        address,
        uint256,
        bytes32,
        bytes32,
        bytes32,
        bytes32,
        uint8,
        uint8,
        Status,
        bool
    ) {
        require(claimExists[id], "claim not found");
        Claim storage c = _claims[id];
        return (
            c.id,
            c.merchant,
            c.amount,
            c.orderHash,
            c.paymentEvidenceHash,
            c.nonDeliveryEvidenceHash,
            c.identityEvidenceHash,
            c.requiredConfirmations,
            c.confirmations,
            c.status,
            c.refundExecuted
        );
    }
}
