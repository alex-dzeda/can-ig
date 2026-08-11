# Record Location Service (RLS) and Patient Discovery

This section specifies the technical architecture, protocol requirements, and operational expectations for Client Applications to discover patient record locations across a CMS-aligned network using the FHIR `$match` (Patient Demographics Match) operation.

---

## Architectural Overview & Context

In a CMS-aligned network, discovering where a patient's medical records reside across distributed Data Holders requires an efficient, standardized Patient Discovery mechanism. Patient Discovery operates under two distinct operational workflows:

1. **Patient Access Workflow (IAS)**: Patient-facing applications query a **Network-Level RLS Endpoint** (Network Broker / Hub) to discover record locations across the ecosystem. Patient Apps **SHALL NOT** execute `$match` queries directly against individual Data Holder endpoints for discovery.
2. **B2B System-to-System Workflow (Provider / Payer)**: Authorized healthcare systems (EHRs, Payers, Connectors) execute `$match` queries directly at Data Holder endpoints or via Network RLS endpoints for treatment, payment, or operations.

---

### Patient Access (IAS) Workflow via Network RLS

For Individual Access Services (IAS), Patient Applications interact with a **Network-Level Record Locator Service (RLS)**:

- **App Authentication via CSP**: The Client Application authenticates the patient out-of-band using an accredited Credential Service Provider (CSP) or Identity Provider, receiving an OIDC `id_token` asserting the patient's verified identity at IAL2.
- **System Access Token & `hl7-b2b` Extension (Client Credentials)**: To query the Network RLS endpoint, the registered Client Application authenticates at the Network token endpoint using `grant_type=client_credentials` with `private_key_jwt` requesting at least the `system/Patient.rs` scope. The presented `client_assertion` **SHALL** include the `hl7-b2b` Authorization Extension Object specifying `purpose_of_use: ["PATRQT"]` (Patient Requested Access) and the requesting application/organization's NPD URI in `organization_id`.
- **IAS Verification Header (`X-IAS-ID-Token`)**: In the `POST /Patient/$match` request to the Network RLS, the Client Application **SHALL** include an `X-IAS-ID-Token` HTTP header containing the patient's verified OIDC `id_token`. The `aud` claim of this `id_token` **SHALL** contain the application's `software_id` URI.
- **Match Certainty & `onlyCertainMatches` Semantics**:
  - **When `onlyCertainMatches = true` (Default for Silent Automated Sync)**: The Network RLS **SHALL** return only 100% verified 1-to-1 patient matches (`search.score = 1.0`). If demographic matching yields multiple candidates for a given Data Holder, that Data Holder **SHALL** be suppressed from the response Bundle to prevent wrong-patient data disclosure.
  - **When `onlyCertainMatches = false` (Comprehensive Candidate Search)**: The Network RLS **MAY** return candidate Data Holder entries where matching is potential/ambiguous (`search.score < 1.0`). For ambiguous matches, the `fullUrl` of the Data Holder endpoint is returned, and the entry **SHALL** include the [MatchStatusExtension](StructureDefinition-match-status-extension.html) set to `#multiple-potential` (`http://example.org/fhir/ig/cms-aligned-network-ig/CodeSystem/match-status-cs#multiple-potential`), indicating that interactive patient verification will be required before clinical data access can be granted.
- **SearchSet Response (`fullUrl`)**: The Network RLS responds with a FHIR `Bundle` of type `searchset`. Every `entry` inside the response Bundle **SHALL** include a valid `fullUrl` element pointing to the absolute FHIR base URL or endpoint of a Data Holder where matching records were found.
- **Targeted Direct Access Bypass**: If a Patient Application already knows the specific target Data Holder (e.g., selected by the user, discovered via NPD, or associated with a prior claim), the application **bypasses `$match` entirely** and proceeds directly to [Token Exchange (`POST /token`)](getting-access-token.html) at the target Data Holder using a SMART Permission Ticket.

---

### B2B & Non-Patient Access Discovery Workflow

For Business-to-Business (B2B) queries (e.g., Provider-to-Provider treatment lookup or Payer-to-Payer coverage checks):

- **Target Endpoints**: Authorized system clients (EHRs, Payers, Connectors) MAY query `$match` either at the Network RLS level or directly at a Data Holder's published `$match` endpoint.
- **Client Credentials & `hl7-b2b` Extension**: The requesting system authenticates via `grant_type=client_credentials` presenting an RFC 7523 `client_assertion` signed by its registered JWKS key. The `client_assertion` **SHALL** include the `hl7-b2b` Authorization Extension Object specifying `purpose_of_use` (e.g. `["TREATMENT"]` or `["HPAYMT"]`) and the requesting organization's NPD URI in `organization_id`.
- **Header Exclusion (Non-Patient Access)**: Non-patient access requests **SHALL NOT** include an `X-IAS-ID-Token` header, as there is no self-authenticating end-user present. Identity authority is asserted purely through the system's `client_credentials` and `hl7-b2b` claims.

---

## Conformance Requirements

The official key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).

1. **Registration Prerequisite**: Client Applications and B2B systems **SHALL** complete [Dynamic Client Registration](registration.html) prior to calling `$match`.
2. **National Provider Directory Publication**: RLS endpoint URLs for Networks and Data Holders **SHALL** be published in the National Provider Directory.
3. **Client Credentials Authentication (`hl7-b2b`)**:
   - Requesters **SHALL** obtain a system access token via `grant_type=client_credentials` using `private_key_jwt` authentication (`client_assertion`).
   - Requesters **SHALL** request at least `system/Patient.rs` in the `scope` parameter.
   - The `client_assertion` JWT presented during `client_credentials` **SHALL** include the `hl7-b2b` claim formatted with `version: "1"`, `purpose_of_use` (`["PATRQT"]` for IAS discovery, or `["TREATMENT"]`/`["HPAYMT"]` for B2B workflows), and `organization_id` set to the requester's NPD URI.
   - Token endpoints **SHALL NOT** return patient launch context inside system client credentials token responses.
4. **IAS Identity Header (`X-IAS-ID-Token`)**:
   - For Patient Access (IAS) discovery workflows, the Client Application **SHALL** include the `X-IAS-ID-Token: <jwt>` HTTP header in the `$match` request to the Network RLS endpoint.
   - The header value **SHALL** contain a valid OIDC `id_token` asserting the patient's verified IAL2 identity.
   - The `aud` claim of the `id_token` **SHALL** match the `software_id` URI specified in the Client Application's CMS-signed software statement.
   - Network RLS endpoints **SHALL** validate that `aud` matches the registered `software_id`, and verify the signature, expiration, and issuer of the `X-IAS-ID-Token` header.
5. **Non-Patient Access Header Omission**:
   - Non-patient access `$match` requests **SHALL NOT** include an `X-IAS-ID-Token` header. Responding endpoints **SHALL** process non-patient access queries based on system authentication and `hl7-b2b` authorization claims.
6. **IAS Match Certainty & Coded Extensions**:
   - When `onlyCertainMatches = true`, Network RLS endpoints **SHALL** return only verified 1-to-1 matches (`search.score = 1.0`). Data Holders with ambiguous matches **MUST** be suppressed.
   - When `onlyCertainMatches = false`, Network RLS endpoints **MAY** return candidate Data Holder entries (`search.score < 1.0`). Candidate entries **SHALL** include the [MatchStatusExtension](StructureDefinition-match-status-extension.html) set to `#multiple-potential` (`http://example.org/fhir/ig/cms-aligned-network-ig/CodeSystem/match-status-cs#multiple-potential`), indicating interactive resolution is required.
7. **Response Bundle & `fullUrl` Requirement**:
   - RLS endpoints **SHALL** respond with HTTP `200 OK` and a `Bundle` of type `searchset`.
   - Every `entry` element inside the response `Bundle` **SHALL** include a non-empty `fullUrl` representing the absolute URL of the matched Patient resource or Data Holder endpoint.
8. **AuditEvent Recording**:
   - Every execution of the `$match` operation **SHALL** be recorded in an `AuditEvent` resource capturing requesting identity (`client_id`), timestamp, `$match` parameter hashes, and resulting match outcome.

---

## Protocol Sequence Diagrams

### Sequence Diagram 1: Patient Access (IAS) Workflow via Network RLS

This sequence illustrates a Patient Access (IAS) discovery query sent to a **Network RLS Endpoint** (`rls.network.example.org`) carrying the verified patient `X-IAS-ID-Token` header:

<p align="center">
  <img src="rls-patient-discovery.svg" alt="IAS Patient Discovery Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
actor "Patient" as Patient
participant "Client Application" as Client
participant "Credential Service Provider (CSP)" as CSP
participant "National Provider Directory" as Directory
participant "Network Token Endpoint" as Token
participant "Network RLS Endpoint" as RLS
database "Network Audit Log" as Audit

group 1. Patient Authentication & Directory Lookup
Patient -> Client: Initiate Record Location Search
Client -> CSP: Authenticate Patient (IAL2)
CSP --> Client: Issue Verified OIDC id_token
Client -> Directory: Lookup Network RLS Endpoint
Directory --> Client: Return RLS Endpoint URL (rls.network.example.org)
end

group 2. Network Client Authentication & RLS Query
Client -> Token: POST /token (grant_type=client_credentials, scope=system/Patient.rs, hl7-b2b PATRQT)
Token --> Client: HTTP 200 OK { access_token, scope: "system/Patient.rs" }
Client -> RLS: POST /Patient/$match\nHeader: Authorization: Bearer <access_token>\nHeader: X-IAS-ID-Token: <id_token>\nBody: Parameters { resource: Patient, onlyCertainMatches: false }
RLS -> RLS: Validate X-IAS-ID-Token signature & Evaluate candidate Data Holders
RLS -> Audit: Log AuditEvent (Client ID, Patient Query, Match Outcomes)
RLS --> Client: HTTP 200 OK Bundle (type=searchset, Data Holder Endpoint entries with match-status extensions)
end
@enduml
```

---

### Sequence Diagram 2: Non-Patient Access (B2B System-to-System) Workflow

This sequence illustrates a Business-to-Business (B2B) treatment or operations discovery query sent directly to a Data Holder endpoint (`dataholder.example.org`). Notice that **NO `X-IAS-ID-Token` header is present**:

<p align="center">
  <img src="rls-patient-discovery_001.svg" alt="Non-Patient Access Discovery Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
participant "Requesting System (EHR / Payer)" as System
participant "National Provider Directory" as Directory
participant "Data Holder /token" as Token
participant "Data Holder $match Endpoint" as DH_RLS
database "Data Holder Audit Log" as Audit

group 1. Directory Discovery
System -> Directory: Lookup Data Holder FHIR Endpoint
Directory --> System: Return Data Holder Endpoint URL (dataholder.example.org)
end

group 2. System Authentication & B2B Match Query
System -> Token: POST /token (grant_type=client_credentials, scope=system/Patient.rs, hl7-b2b TREATMENT)
Token --> System: HTTP 200 OK { access_token, scope: "system/Patient.rs" }
System -> DH_RLS: POST /Patient/$match\nHeader: Authorization: Bearer <access_token>\n(NO X-IAS-ID-Token Header)\nBody: Parameters { resource: Patient, onlyCertainMatches: true }
DH_RLS -> DH_RLS: Validate system access_token & hl7-b2b TREATMENT claim
DH_RLS -> Audit: Log AuditEvent (System ID, Purpose of Use, Match Result)
DH_RLS --> System: HTTP 200 OK Bundle (type=searchset, Matched Patient Resource fullUrl)
end
@enduml
```

---

## HTTP Exchange Examples

### Example Set 1: Individual Access Services (IAS) via Network RLS Endpoint

This example demonstrates a Patient Access (IAS) discovery query sent to a **Network RLS Endpoint** (`rls.network.example.org`) presenting the `X-IAS-ID-Token` header.

#### Step 1: System Access Token Request at Network (`POST /token`)

```http
POST /oauth/token HTTP/1.1
Host: rls.network.example.org
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzM4NCIsImtpZCI6ImFwcC1rZXktMSJd...[client-assertion-jwt]...
&scope=system%2FPatient.rs
```

##### Example `client_assertion` JWT Payload (with `hl7-b2b` Extension for IAS Discovery)

```json
{
  "iss": "ias_client_app_88120",
  "sub": "ias_client_app_88120",
  "aud": "https://rls.network.example.org/oauth/token",
  "exp": 1781817583,
  "iat": 1781817283,
  "jti": "ias-b2b-token-req-9912",
  "hl7-b2b": {
    "version": "1",
    "purpose_of_use": [
      "PATRQT"
    ],
    "organization_id": "https://directory.cms.gov/organizations/app-org-99281"
  }
}
```

##### Network Token Response

```http
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
Cache-Control: no-store

{
  "access_token": "eyJhbGciOiJSUzI1Ni...[network_system_token]...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "system/Patient.rs"
}
```

#### Step 2: IAS Patient Discovery Query to Network RLS (`POST /Patient/$match`)

```http
POST /fhir/Patient/$match HTTP/1.1
Host: rls.network.example.org
Authorization: Bearer eyJhbGciOiJSUzI1Ni...[network_system_token]...
X-IAS-ID-Token: eyJhbGciOiJSUzI1NiIsImtpZCI6ImNzcC1rZXktMSJd...[verified-id-token]...
Content-Type: application/fhir+json

{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [
          {
            "family": "Smith",
            "given": ["Jane"]
          }
        ],
        "birthDate": "1985-04-12",
        "gender": "female",
        "identifier": [
          {
            "system": "http://hl7.org/fhir/sid/us-mbi",
            "value": "1EG4-TE5-MK73"
          }
        ]
      }
    },
    {
      "name": "onlyCertainMatches",
      "valueBoolean": false
    }
  ]
}
```

#### Step 3: Network RLS SearchSet Response (Endpoint List with Match Status)

The Network RLS returns a `searchset` Bundle containing Data Holder `Endpoint` resources across member health systems, highlighting a `#certain` match (`Hospital A`) and a `#multiple-potential` match (`Mayo Clinic` requiring interactive resolution):

```http
HTTP/1.1 200 OK
Content-Type: application/fhir+json;charset=UTF-8

{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 2,
  "entry": [
    {
      "fullUrl": "https://hospital-a.example.org/fhir",
      "resource": {
        "resourceType": "Endpoint",
        "status": "active",
        "name": "Hospital A FHIR Endpoint",
        "address": "https://hospital-a.example.org/fhir"
      },
      "search": {
        "mode": "match",
        "score": 1.0,
        "extension": [
          {
            "url": "http://example.org/fhir/ig/cms-aligned-network-ig/StructureDefinition/match-status-extension",
            "valueCoding": {
              "system": "http://example.org/fhir/ig/cms-aligned-network-ig/CodeSystem/match-status-cs",
              "code": "certain",
              "display": "Certain Match"
            }
          }
        ]
      }
    },
    {
      "fullUrl": "https://mayoclinic.example.org/fhir",
      "resource": {
        "resourceType": "Endpoint",
        "status": "active",
        "name": "Mayo Clinic FHIR Endpoint",
        "address": "https://mayoclinic.example.org/fhir"
      },
      "search": {
        "mode": "match",
        "score": 0.5,
        "extension": [
          {
            "url": "http://example.org/fhir/ig/cms-aligned-network-ig/StructureDefinition/match-status-extension",
            "valueCoding": {
              "system": "http://example.org/fhir/ig/cms-aligned-network-ig/CodeSystem/match-status-cs",
              "code": "multiple-potential",
              "display": "Multiple Potential Matches"
            }
          }
        ]
      }
    }
  ]
}
```

---

### Example Set 2: B2B System-to-System Discovery directly at Data Holder Endpoint

This example demonstrates a Business-to-Business (B2B) treatment query sent directly to a Data Holder endpoint (`dataholder.example.org`). **NO `X-IAS-ID-Token` header is present.**

#### Step 1: System Access Token Request at Data Holder (`POST /token`)

```http
POST /oauth/token HTTP/1.1
Host: dataholder.example.org
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=eyJhbGciOiJFUzM4NCIsImtpZCI6ImFwcC1rZXktMSJd...[client-assertion-jwt]...
&scope=system%2FPatient.rs
```

##### Example `client_assertion` JWT Payload (B2B Treatment Request)

```json
{
  "iss": "b2b_ehr_system_4410",
  "sub": "b2b_ehr_system_4410",
  "aud": "https://dataholder.example.org/oauth/token",
  "exp": 1781817583,
  "iat": 1781817283,
  "jti": "b2b-treatment-req-7712",
  "hl7-b2b": {
    "version": "1",
    "purpose_of_use": [
      "TREATMENT"
    ],
    "organization_id": "https://directory.cms.gov/organizations/hospital-b-991"
  }
}
```

##### Data Holder Token Response

```http
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
Cache-Control: no-store

{
  "access_token": "eyJhbGciOiJSUzI1Ni...[b2b_system_access_token]...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "system/Patient.rs"
}
```

#### Step 2: B2B Direct Patient Discovery Query (`POST /Patient/$match`)

Notice that **NO `X-IAS-ID-Token` header is present** in the B2B request:

```http
POST /fhir/Patient/$match HTTP/1.1
Host: dataholder.example.org
Authorization: Bearer eyJhbGciOiJSUzI1Ni...[b2b_system_access_token]...
Content-Type: application/fhir+json

{
  "resourceType": "Parameters",
  "parameter": [
    {
      "name": "resource",
      "resource": {
        "resourceType": "Patient",
        "name": [
          {
            "family": "Smith",
            "given": ["Jane"]
          }
        ],
        "birthDate": "1985-04-12",
        "gender": "female"
      }
    },
    {
      "name": "onlyCertainMatches",
      "valueBoolean": true
    }
  ]
}
```

#### Step 3: Data Holder SearchSet Response (Local Patient Match)

The Data Holder responds directly with a `searchset` Bundle containing the local matched `Patient` resource:

```http
HTTP/1.1 200 OK
Content-Type: application/fhir+json;charset=UTF-8

{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 1,
  "entry": [
    {
      "fullUrl": "https://dataholder.example.org/fhir/Patient/pat-88321",
      "resource": {
        "resourceType": "Patient",
        "id": "pat-88321",
        "name": [
          {
            "family": "Smith",
            "given": ["Jane"]
          }
        ],
        "birthDate": "1985-04-12",
        "gender": "female"
      },
      "search": {
        "mode": "match",
        "score": 1.0,
        "extension": [
          {
            "url": "http://example.org/fhir/ig/cms-aligned-network-ig/StructureDefinition/match-status-extension",
            "valueCoding": {
              "system": "http://example.org/fhir/ig/cms-aligned-network-ig/CodeSystem/match-status-cs",
              "code": "certain",
              "display": "Certain Match"
            }
          }
        ]
      }
    }
  ]
}
```

---

## Auditability Expectations (`AuditEvent`)

Every execution of the `$match` operation **SHALL** be recorded in an audit trail. Data Holders **SHALL** generate a FHIR `AuditEvent` resource for each Patient Discovery query. 

> [!IMPORTANT]
> **UNDER CONSTRUCTION**: Detailed profiles and operational guidelines for `AuditEvent` resources supporting RLS and Patient Discovery are under construction and need to be reconciled with the *CMS Aligned Network Audit Specification*.

Key audit attributes recorded include:
- **`type`**: Restful Operation (`http://terminology.hl7.org/CodeSystem/audit-event-type` code `rest`).
- **`subtype`**: Operation `$match` (`http://hl7.org/fhir/restful-interaction` code `operation`).
- **`agent`**: The authenticated Client Application (`client_id`) and user identity extracted from `X-IAS-ID-Token`.
- **`entity`**: The query parameters (hashed demographic search parameters) and resulting matched Patient ID (`fullUrl`).

---

## Points for Discussion

> [!IMPORTANT]
> - **Placement of the ID Token**: The placement of the OIDC `id_token` (e.g. `X-IAS-ID-Token` header) in this workflow is **not finalized** and remains under active consideration. While the verified patient assertion could theoretically be conveyed using SMART Permission Tickets during token exchange, doing so for initial Patient Discovery would result in a clunky, multi-hop interface. Ongoing evaluations are considering the optimal balance between header assertions and ticket-based mechanisms.
> - **B2B Match Certainty (`onlyCertainMatches`)**: Since there is no interaction potential in automated B2B system-to-system flows to perform real-time patient disambiguation, should B2B discovery workflows strictly mandate `onlyCertainMatches=true` to prevent wrong-patient data exposure?
