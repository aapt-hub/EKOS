# EKOS.SecurityPlus.Schema.psm1
# Deterministic schema layer for SY0-701 ingestion

Set-StrictMode -Version Latest

# -----------------------------
# DOMAIN DEFINITIONS
# -----------------------------

$Global:EKOS_SecurityPlus_Domains = @{
    D1 = "General Security Concepts"
    D2 = "Threats, Vulnerabilities, and Mitigations"
    D3 = "Security Architecture"
    D4 = "Security Operations"
    D5 = "Security Program Management and Oversight"
}

# -----------------------------
# COMPETENCY SCHEMA (ATOMIC NODES)
# -----------------------------

function New-EkosSecurityCompetency {
    param(
        [string]$Id,
        [string]$Domain,
        [string]$Concept,
        [string[]]$Signals,
        [string[]]$ExpectedOutputs
    )

    return [pscustomobject]@{
        Id = $Id
        Domain = $Domain
        Concept = $Concept
        Signals = $Signals
        ExpectedOutputs = $ExpectedOutputs
        Type = "SecurityPlusCompetency"
    }
}

# -----------------------------
# CORE COMPETENCIES (INITIAL SEED)
# -----------------------------

$Global:EKOS_SecurityPlus_Competencies = @(
    
    # D1 - Cryptography
    New-EkosSecurityCompetency `
        -Id "D1_CRYPTO_SYMMETRIC" `
        -Domain "D1" `
        -Concept "symmetric_encryption" `
        -Signals @("shared_secret", "fast_encryption", "bulk_data") `
        -ExpectedOutputs @("AES", "DES", "ChaCha20")

    New-EkosSecurityCompetency `
        -Id "D1_CRYPTO_ASYMMETRIC" `
        -Domain "D1" `
        -Concept "asymmetric_encryption" `
        -Signals @("public_private_key", "key_exchange", "PKI") `
        -ExpectedOutputs @("RSA", "ECC")

    New-EkosSecurityCompetency `
        -Id "D1_HASHING" `
        -Domain "D1" `
        -Concept "hash_functions" `
        -Signals @("one_way", "integrity_check", "fixed_output") `
        -ExpectedOutputs @("SHA-256", "SHA-3")

    # D2 - Threats
    New-EkosSecurityCompetency `
        -Id "D2_BRUTE_FORCE" `
        -Domain "D2" `
        -Concept "brute_force_attack" `
        -Signals @("failed_login_spike", "repeated_auth_attempts") `
        -ExpectedOutputs @("block_ip", "account_lockout")

    New-EkosSecurityCompetency `
        -Id "D2_SOCIAL_ENGINEERING" `
        -Domain "D2" `
        -Concept "social_engineering" `
        -Signals @("human_targeting", "phishing", "pretexting") `
        -ExpectedOutputs @("user_awareness", "email_filtering")

    # D3 - Architecture
    New-EkosSecurityCompetency `
        -Id "D3_NETWORK_SEGMENTATION" `
        -Domain "D3" `
        -Concept "dmz_and_segmentation" `
        -Signals @("firewall_zones", "dmz", "internal_network") `
        -ExpectedOutputs @("web_in_dmz", "db_internal")

    # D4 - Operations
    New-EkosSecurityCompetency `
        -Id "D4_LOG_ANALYSIS" `
        -Domain "D4" `
        -Concept "siem_log_analysis" `
        -Signals @("event_logs", "correlation", "timestamps") `
        -ExpectedOutputs @("attack_classification", "ip_extraction")

    # D5 - Governance
    New-EkosSecurityCompetency `
        -Id "D5_RISK_MODEL" `
        -Domain "D5" `
        -Concept "risk_scoring" `
        -Signals @("likelihood", "impact") `
        -ExpectedOutputs @("risk_score", "mitigation_plan")
)

# -----------------------------
# PBQ SCHEMA CONTRACT
# -----------------------------

function New-EkosPBQ {
    param(
        [string]$Domain,
        [string]$Scenario,
        [string[]]$Tasks,
        [string[]]$ExpectedStructure
    )

    return [pscustomobject]@{
        Domain = $Domain
        Scenario = $Scenario
        Tasks = $Tasks
        ExpectedStructure = $ExpectedStructure
        Type = "PBQ"
    }
}

# -----------------------------
# DEFAULT PBQ TEMPLATES
# -----------------------------

$Global:EKOS_SecurityPlus_PBQs = @(

    New-EkosPBQ `
        -Domain "D2" `
        -Scenario "SSH logs show repeated failed logins followed by success" `
        -Tasks @("identify_attack", "extract_indicator", "select_action") `
        -ExpectedStructure @("attack_type", "ip_address", "containment_action")

    New-EkosPBQ `
        -Domain "D3" `
        -Scenario "Design secure network with DMZ and internal database" `
        -Tasks @("place_web_server", "place_db_server", "define_firewall_rules") `
        -ExpectedStructure @("dmz_web", "internal_db", "stateful_firewall")
)

# -----------------------------
# VALIDATION RULES (DRIFT-READY)
# -----------------------------

function Test-EkosSecurityAnswerSchema {
    param($Answer)

    $required = @("attack_type", "action", "indicator")

    foreach ($r in $required) {
        if (-not $Answer.PSObject.Properties.Name -contains $r) {
            return $false
        }
    }

    return $true
}

Export-ModuleMember -Function *