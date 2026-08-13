# Dynamic Client Registration — OpenID Federation 1.0 (Sequential Delegation Model)

This section specifies an alternative **OpenID Federation 1.0 Sequential Delegation Architecture** for Client Applications connecting to Data Holders within a CMS-aligned network.

In this architecture, trust is established natively using **OpenID Federation 1.0 (OIDF)** linear JSON Web Key Set (JWKS) trust chains anchored in a CMS Trust Anchor. This model combines **CMS as a trust anchor, publishing a base set of verified application information**, with **Home Network operational delegation**, eliminating the need for traditional X.509 Certificate Authorities (`x5c`).

---

## Architectural & Protocol Overview

The Sequential Delegation Model operates in two distinct, sequential phases:
1. **Phase 1 (CMS Onboarding & Base Attestation)**: The Client Application registers out-of-band with CMS, which confirms specific information submitted by the application (including domain ownership and app-hosted `jwks_uri` at `https://bpbuddy.example.com/.well-known/jwks.json`), and issues a **CMS App Base Statement** (`CMS_App_Statement`) containing the verified `jwks_uri` for the app's canonical CMS Entity ID (`https://library.medicare.gov/apps/bpbuddy`). The application presents this CMS Base Statement to an accredited Home Network to join the network.
2. **Phase 2 (Operational Data Holder Registration)**: Upon confirming active network standing, Home Network A issues a **Network-Delegated Statement** (`Network_Delegated_Statement`). When registering or requesting tokens from a Data Holder, the application presents a linear 3-tier OpenID Federation `trust_chain` directly in the request payload.

```
[Phase 1: CMS Base Onboarding]
App Developer ───> CMS App Library ───(Confirms App Info & Verifies App JWKS)───> Issues CMS App Base Statement
                                                                                            │
App Developer ───> Home Network A  ───(Presents CMS Base Statement)─────────────────────────┘

[Phase 2: Data Holder Dynamic Registration / Token Exchange]
App ───(Presents Linear 3-Tier Trust Chain in Request Payload)───> Data Holder /register or /token
        │
        ├── [0: App Entity Configuration] (Self-signed by App Private Key, passed inline)
        ├── [1: Network Delegated Statement] (Signed by Home Network A, embeds CMS standing)
        └── [2: CMS Network Accreditation] (Signed by CMS Root Trust Anchor)
```

---

## Protocol Sequence Diagram

<p align="center">
  <img src="registration-openid-federation.svg" alt="OpenID Federation Dynamic Registration Sequence Diagram" style="max-width: 100%; height: auto;" />
</p>

```plantuml
@startuml
scale max 1000 width
autonumber
actor "App Developer / App" as App
participant "CMS App Library & TA" as CMS
participant "Home Network Authority" as Network
participant "Data Holder /register" as DH

group Phase 1: CMS Base Onboarding & Network Delegation
App -> CMS: Submit Software Information & App-Hosted jwks_uri
CMS -> CMS: Confirm App Info & Verify App JWKS (https://bpbuddy.example.com/.well-known/jwks.json)
CMS -> App: Issue CMS App Base Statement (CMS_App_Statement for https://library.medicare.gov/apps/bpbuddy)
App -> Network: Present CMS_App_Statement & Request Network Membership
Network -> Network: Verify CMS Signature & Confirm Network Standing
Network -> App: Issue Network-Delegated Statement (Network_Delegated_Statement)
end

group Phase 2: OpenID Federation Dynamic Registration (Explicit Model)
App -> DH: POST /register { trust_chain: [App_EC, Network_Delegated_Statement, CMS_Network_Accreditation], client_assertion }
DH -> DH: Validate Linear 3-Tier Trust Chain (CMS Root Anchor -> Network -> App)
DH -> DH: Verify App Key Possession via client_assertion against App jwks_uri
DH --> App: HTTP 201 Created { client_id: "dh-assigned-88192" }
end
@enduml
```

---

## Dynamic Registration Architectural Scope

OpenID Federation 1.0 natively supports two operational registration patterns:

* **Explicit Client Registration (Stateful Governance Model — IN SCOPE)**: The client application **SHALL** execute a standard `POST /register` call (RFC 7591) presenting its 3-tier `trust_chain` and proof-of-possession `client_assertion` to receive a server-assigned `client_id`.
* **Automatic Client Registration (Stateless Model — OUT OF SCOPE)**: While OpenID Federation 1.0 natively allows stateless automatic registration during token requests without pre-registration, this pattern is marked as **Out of Scope** for the current version of this specification to focus on establishing foundational explicit registration patterns before introducing stateless token-exchange models.

Implementers **SHALL** use **Explicit Client Registration (`POST /register`)**.

---

## Technical Specifications & Payload Normative Conformance

### OpenID Federation Entity Statement Overview

In OpenID Federation 1.0, trust relationships, metadata policies, and public key assertions are represented as signed JSON Web Tokens (JWTs) called **Entity Statements**. 

* **Entity Configuration**: A self-signed statement created by an entity attesting its own capabilities and public keys. For Client Applications whose `iss` is assigned under CMS (`https://library.medicare.gov/apps/bpbuddy`), the `App_EC` is self-signed by the app developer using their private key and submitted inline within the `trust_chain` payload (eliminating the need for the app to host web endpoints under `library.medicare.gov`).
* **Subordinate Entity Statement**: A statement issued by a superior entity (e.g. CMS or Home Network) about a subordinate entity (e.g. Home Network or App) attesting accreditation or delegation.

Every Entity Statement **SHALL** use the JOSE header media type `entity-statement+jwt` and contain standard JOSE header and payload parameters:

#### Compact Serialized Entity Statement (JWT String Example)
```
eyJhbGciOiJFUzI1NiIsImtpZCI6ImNtcy10cnVzdC1hbmNob3Ita2V5LTIwMjYiLCJ0eXAiOiJlbnRpdHktc3RhdGVtZW50K2p3dCJ9.eyJpc3MiOiJodHRwczovL2xpYnJhcnkuY21zLmdvdiIsInN1YiI6Imh0dHBzOi8vbmV0d29yay1hLm9yZyIsImlhdCI6MTc2OTk5NjQwMCwiZXhwIjoxNzcwMDgyODAwLCJqd2tzIjp7ImtleXMiOlt7Imt0eSI6IkVDIiwiY3J2IjoiUC0yNTYiLCJraWQiOiJuZXR3b3JrLWEta2V5LTIwMjYiLCJ4IjoiZjgzT0ozRDJ4RDEuLi4iLCJ5IjoieF85bzh3UzFCLi4uIn1dfSwiYXV0aG9yaXR5X2hpbnRzIjpbImh0dHBzOi8vbGlicmFyeS5jbXMuZ292Il19.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

#### Generic Decoded Entity Statement Payload Structure
```json
{
  "header": {
    "alg": "ES256",
    "kid": "authority-signing-key-id",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://authority.example.org",
    "sub": "https://subordinate.example.org",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks": {
      "keys": [...]
    },
    "authority_hints": [
      "https://trust-anchor.example.org"
    ],
    "metadata_policy": { ... },
    "extensions": { ... }
  }
}
```

---

### CMS Root Trust Anchor Entity Configuration (`CMS_Root_Entity_Configuration`)

Published self-signed by the CMS Trust Anchor at `https://library.cms.gov/.well-known/openid-federation`. This statement establishes the public Root JWKS for the entire CMS network federation.

#### HTTP Response from `GET https://library.cms.gov/.well-known/openid-federation`

```http
HTTP/1.1 200 OK
Content-Type: application/entity-statement+jwt
Cache-Control: max-age=86400

eyJhbGciOiJFUzI1NiIsImtpZCI6ImNtcy1yb290LWFuY2hvci1rZXktMjAyNiIsInR5cCI6ImVudGl0eS1zdGF0ZW1lbnQrancifQ...[Compact Signed JWT]
```

#### JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Approved signature algorithm (`ES256` or `RS256`). |
| `kid` | **SHALL** | String | Key Identifier matching the CMS Root Trust Anchor signing key. |
| `typ` | **SHALL** | String | **SHALL** be `entity-statement+jwt`. |

#### Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer (**SHALL** be `https://library.cms.gov`). |
| `sub` | **SHALL** | String (URI) | Subject (**SHALL** be `https://library.cms.gov`). |
| `iat` | **SHALL** | Integer | Epoch timestamp when statement was issued. |
| `exp` | **SHALL** | Integer | Epoch timestamp when statement expires. |
| `jwks` | **SHALL** | Object (JWKS) | Public Root JWKS of the CMS Trust Anchor used to verify all subordinate network statements. |
| `metadata.federation_entity` | **SHALL** | Object | Endpoints including `federation_fetch_endpoint`, `federation_list_endpoint`, and `federation_status_list_endpoint`. |

##### Decoded Example `CMS_Root_Entity_Configuration` (`/.well-known/openid-federation`)
```json
{
  "header": {
    "alg": "ES256",
    "kid": "cms-root-anchor-key-2026",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://library.cms.gov",
    "sub": "https://library.cms.gov",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks": {
      "keys": [
        {
          "kty": "EC",
          "crv": "P-256",
          "kid": "cms-root-anchor-key-2026",
          "x": "W89OJ3D2xD1...",
          "y": "y_9o8wS1B..."
        }
      ]
    },
    "metadata": {
      "federation_entity": {
        "organization_name": "Centers for Medicare & Medicaid Services (CMS)",
        "contacts": [
          "federation-admin@cms.gov"
        ],
        "federation_fetch_endpoint": "https://library.cms.gov/fetch",
        "federation_list_endpoint": "https://library.cms.gov/list",
        "federation_status_list_endpoint": "https://library.medicare.gov/.well-known/status-list.json"
      }
    }
  }
}
```

---

### CMS Network Accreditation Statement (`CMS_Network_Statement`)

Issued by the CMS Trust Anchor (`https://library.cms.gov`) to accredit Home Network A (`https://network-a.org`) as an Intermediate Authority.

#### JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Approved signature algorithm (e.g. `ES256` or `RS256`). |
| `kid` | **SHALL** | String | Key Identifier matching the CMS Root Trust Anchor key. |
| `typ` | **SHALL** | String | **SHALL** be `entity-statement+jwt`. |

#### Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer of the statement (**SHALL** be `https://library.cms.gov`). |
| `sub` | **SHALL** | String (URI) | Subject Home Network Entity ID (**SHALL** match accredited Home Network URL). |
| `iat` | **SHALL** | Integer | Epoch timestamp when statement was issued. |
| `exp` | **SHALL** | Integer | Epoch timestamp when statement expires. |
| `jwks` | **SHALL** | Object (JWKS) | Home Network's public key set. Can contain multiple keys (`[old_key, new_key]`) for zero-downtime rotation. |
| `authority_hints` | **SHALL** | Array of Strings | **SHALL** contain `["https://library.cms.gov"]`. |
| `constraints` | **MAY** | Object | OpenID Federation path length restrictions (`max_path_length`) and entity type constraints (`allowed_entity_types`). |

##### Decoded Example `CMS_Network_Statement`
```json
{
  "header": {
    "alg": "ES256",
    "kid": "cms-root-anchor-key-2026",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://library.cms.gov",
    "sub": "https://network-a.org",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks": {
      "keys": [
        {
          "kty": "EC",
          "crv": "P-256",
          "kid": "network-a-key-2026",
          "x": "f83OJ3D2xD1...",
          "y": "x_9o8wS1B..."
        },
        {
          "kty": "EC",
          "crv": "P-256",
          "kid": "network-a-key-2027",
          "x": "m91KS92aK2...",
          "y": "pL8192aM..."
        }
      ]
    },
    "authority_hints": [
      "https://library.cms.gov"
    ],
    "constraints": {
      "max_path_length": 1,
      "allowed_entity_types": [
        "openid_relying_party"
      ]
    }
  }
}
```

---

### CMS App Base Statement (`CMS_App_Statement`)

Issued by CMS (`https://library.cms.gov`) during Phase 1 onboarding to confirm application information and bind the application's verified `jwks_uri`. Data Holders can retrieve this statement directly from CMS's fetch endpoint (`GET https://library.cms.gov/fetch?sub=https%3A%2F%2Flibrary.medicare.gov%2Fapps%2Fbpbuddy`) or verify the CMS claims passed transitively inside `Network_Delegated_Statement`.

#### JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Approved signature algorithm (e.g. `ES256` or `RS256`). |
| `kid` | **SHALL** | String | Key Identifier matching the CMS Root Trust Anchor key. |
| `typ` | **SHALL** | String | **SHALL** be `entity-statement+jwt`. |

#### Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer of the statement (**SHALL** be `https://library.cms.gov`). |
| `sub` | **SHALL** | String (URI) | Subject Application Software ID (**SHALL** match canonical app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `iat` | **SHALL** | Integer | Epoch timestamp when statement was issued. |
| `exp` | **SHALL** | Integer | Epoch timestamp when statement expires. |
| `jwks_uri` | **SHALL** | String (URL) | Verified app-hosted public key URL (`https://bpbuddy.example.com/.well-known/jwks.json`). |
| `metadata` | **SHALL** | Object | Client metadata including `client_name`, `client_uri`, and `contacts`. |
| `extensions.cms_app` | **SHALL** | Object | Application status extensions, app version, and Bitstring Status List revocation parameters (`url` and `index`). |

##### Decoded Example `CMS_App_Statement`
```json
{
  "header": {
    "alg": "ES256",
    "kid": "cms-root-anchor-key-2026",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://library.cms.gov",
    "sub": "https://library.medicare.gov/apps/bpbuddy",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks_uri": "https://bpbuddy.example.com/.well-known/jwks.json",
    "metadata": {
      "client_name": "BP Buddy PHR",
      "client_uri": "https://bpbuddy.example.com",
      "contacts": ["admin@bpbuddy.example.com"]
    },
    "extensions": {
      "cms_app": {
        "version": "1.0",
        "app_class": "patient-access-app",
        "app_status": "active",
        "status_list": {
          "url": "https://library.medicare.gov/.well-known/status-list.json",
          "index": 4092
        }
      }
    }
  }
}
```

---

### Network-Delegated Statement (`Network_Delegated_Statement`)

Issued by Home Network A (`https://network-a.org`) during Phase 2 to accredit the application for Data Holder registration based on its verified `CMS_App_Statement`.

#### JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Approved signature algorithm (e.g. `ES256`). |
| `kid` | **SHALL** | String | Key Identifier matching the Home Network's active signing key. |
| `typ` | **SHALL** | String | **SHALL** be `entity-statement+jwt`. |

#### Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer of the delegated statement (**SHALL** be Home Network URL). |
| `sub` | **SHALL** | String (URI) | Subject Application Software ID (**SHALL** match canonical app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `iat` | **SHALL** | Integer | Epoch timestamp when statement was issued. |
| `exp` | **SHALL** | Integer | Epoch timestamp when statement expires (**SHOULD NOT** exceed 7 days). |
| `jwks_uri` | **SHALL** | String (URL) | Verified app public key URL (`https://bpbuddy.example.com/.well-known/jwks.json`). |
| `authority_hints` | **SHALL** | Array of Strings | **SHALL** contain `["https://library.cms.gov"]`. |
| `metadata_policy` | **SHALL** | Object | Policy constraints restricting allowed `grant_types` and `scope` (`subset_of`). |
| `extensions.network_delegation` | **SHALL** | Object | Home network standing and purpose of use (`PATRQT`). |
| `extensions.cms_app` | **SHALL** | Object | Transitive CMS app status (`app_status: "active"`) and Bitstring Status List revocation parameters (`url` and `index`). |

##### Decoded Example `Network_Delegated_Statement`
```json
{
  "header": {
    "alg": "ES256",
    "kid": "network-a-key-2026",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://network-a.org",
    "sub": "https://library.medicare.gov/apps/bpbuddy",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks_uri": "https://bpbuddy.example.com/.well-known/jwks.json",
    "authority_hints": [
      "https://library.cms.gov"
    ],
    "metadata_policy": {
      "grant_types": {
        "subset_of": [
          "authorization_code",
          "refresh_token",
          "urn:ietf:params:oauth:grant-type:token-exchange",
          "client_credentials"
        ]
      },
      "scope": {
        "subset_of": ["patient/*.rs", "openid", "fhirUser"]
      }
    },
    "extensions": {
      "network_delegation": {
        "home_network_id": "https://network-a.org",
        "standing": "active",
        "purpose_of_use": "PATRQT"
      },
      "cms_app": {
        "app_status": "active",
        "status_list": {
          "url": "https://library.medicare.gov/.well-known/status-list.json",
          "index": 4092
        }
      }
    }
  }
}
```

---

### Leaf App Entity Configuration (`App_EC`)

Self-signed by the application developer using the private key matching `jwks_uri`. Because the app's canonical `iss` is `https://library.medicare.gov/apps/bpbuddy`, the application **SHALL NOT** host web endpoints under `library.medicare.gov`; instead, the application presents `App_EC` directly inline as `trust_chain[0]` within registration and token requests.

#### JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Signature algorithm matching a public key in the app's JWKS. |
| `kid` | **SHALL** | String | Key Identifier of the active public key in the app's JWKS. |
| `typ` | **SHALL** | String | **SHALL** be `entity-statement+jwt`. |

#### Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer (**SHALL** match canonical app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `sub` | **SHALL** | String (URI) | Subject (**SHALL** match canonical app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `iat` | **SHALL** | Integer | Epoch timestamp when statement was issued. |
| `exp` | **SHALL** | Integer | Epoch timestamp when statement expires. |
| `jwks` | **SHALL** | Object (JWKS) | Public Key Set of the App (matching private key used for `client_assertion`). |
| `authority_hints` | **SHALL** | Array of Strings | **SHALL** contain `["https://network-a.org"]`. |
| `metadata.openid_client` | **SHALL** | Object | OAuth/SMART client metadata (`client_name`, `client_uri`, `redirect_uris`, `grant_types`, `scope`, `token_endpoint_auth_method`). |

##### Decoded Example `App_EC` (`trust_chain[0]`)
```json
{
  "header": {
    "alg": "ES256",
    "kid": "bpbuddy-app-key-01",
    "typ": "entity-statement+jwt"
  },
  "payload": {
    "iss": "https://library.medicare.gov/apps/bpbuddy",
    "sub": "https://library.medicare.gov/apps/bpbuddy",
    "iat": 1769996400,
    "exp": 1770082800,
    "jwks": {
      "keys": [
        {
          "kty": "EC",
          "crv": "P-256",
          "kid": "bpbuddy-app-key-01",
          "x": "us9812aK...",
          "y": "mK8912uB..."
        }
      ]
    },
    "authority_hints": [
      "https://network-a.org"
    ],
    "metadata": {
      "openid_client": {
        "client_name": "BP Buddy PHR",
        "client_uri": "https://bpbuddy.example.com",
        "redirect_uris": [
          "https://bpbuddy.example.com/oauth/callback"
        ],
        "grant_types": [
          "authorization_code",
          "refresh_token",
          "urn:ietf:params:oauth:grant-type:token-exchange",
          "client_credentials"
        ],
        "response_types": [
          "code"
        ],
        "scope": "patient/*.rs openid fhirUser",
        "token_endpoint_auth_method": "private_key_jwt"
      }
    }
  }
}
```

---

### Proof of Key Possession (`client_assertion`)

To prove possession of the private key matching the public key published at `jwks_uri`, the Client Application **SHALL** present a self-contained Key Possession JWT using standard RFC 7523 `private_key_jwt` parameters.

#### Key Possession JOSE Header Conformance

| Header Parameter | Conformance | Type | Value / Requirement |
| :--- | :--- | :--- | :--- |
| `alg` | **SHALL** | String | Signature algorithm matching an active public key in the app's JWKS. |
| `kid` | **SHALL** | String | Key Identifier of the active public key in the app's JWKS. |
| `typ` | **SHALL** | String | **SHALL** be `JWT`. |

#### Key Possession Payload Claims Conformance

| Claim Name | Conformance | Type | Description |
| :--- | :--- | :--- | :--- |
| `iss` | **SHALL** | String (URI) | Issuer of assertion (**SHALL** match app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `sub` | **SHALL** | String (URI) | Subject of assertion (**SHALL** match app Entity ID `https://library.medicare.gov/apps/bpbuddy`). |
| `aud` | **SHALL** | String (URI) | Audience (**SHALL** match Data Holder's absolute `/register` or `/token` URL). |
| `exp` | **SHALL** | Integer | Epoch expiration. **SHALL NOT** exceed 5 minutes from `iat`. |
| `iat` | **SHALL** | Integer | Epoch issue timestamp. |
| `jti` | **SHALL** | String | Unique nonce identifier to prevent replay. |

---

## Concrete End-to-End Registration Examples

Below is a concrete, complete HTTP request and response example demonstrating **Explicit Client Registration (`POST /register`)**.

> [!NOTE]
> **Automatic Registration Out of Scope**: OpenID Federation 1.0 supports stateless Automatic Registration during token requests; however, for the current version of this specification, implementers **SHALL** use the Explicit Client Registration pattern below.

### Explicit Client Registration Request (`POST /register`)

The application presents its linear 3-tier `trust_chain` and proof-of-possession `client_assertion` to the Data Holder's `/register` endpoint (RFC 7591):

```http
POST /register HTTP/1.1
Host: dataholder.example.org
Content-Type: application/json

{
  "trust_chain": [
    "eyJhbGciOiJ...[0: Leaf App Entity Configuration (App_EC)]",
    "eyJhbGciOiJ...[1: Network-Delegated Statement (Network_Delegated_Statement)]",
    "eyJhbGciOiJ...[2: CMS Network Accreditation Statement (CMS_Network_Statement)]"
  ],
  "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
  "client_assertion": "eyJhbGciOiJ...[App Key Proof-of-Possession JWT]",
  "redirect_uris": [
    "https://bpbuddy.example.com/oauth/callback"
  ],
  "scope": "patient/*.rs"
}
```

### Data Holder Registration Response (`HTTP 201 Created`)

The Data Holder validates the `trust_chain`, creates a persistent client record, and returns the registration output:

```http
HTTP/1.1 201 Created
Content-Type: application/json
Cache-Control: no-store

{
  "client_id": "dh-assigned-88192",
  "client_id_issued_at": 1769996400,
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "authorization_code",
    "refresh_token",
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "client_credentials"
  ],
  "response_types": [
    "code"
  ],
  "redirect_uris": [
    "https://bpbuddy.example.com/oauth/callback"
  ],
  "scope": "patient/*.rs"
}
```

---

## Data Holder Validation Algorithm & Revocation Rules

Data Holders **SHALL** execute the following verification sequence upon receiving an OpenID Federation registration or token request:

1. **Extract & Decode Inline Trust Chain**:
   - Extract `trust_chain` array from request parameters or JSON body. Confirm it contains 3 valid, Base64URL-encoded compact JWT strings.
   - If missing or malformed, reject with `HTTP 400 Bad Request` (`error="invalid_request"`).

2. **Linear Path Signature Verification (Root to Leaf)**:
   - **Step 2a (CMS Anchor)**: Verify signature of `trust_chain[2]` (`CMS_Network_Statement`) against local CMS Root JWKS store (`https://library.cms.gov/.well-known/openid-federation`).
   - **Step 2b (Network Delegation)**: Extract public key from `trust_chain[2]`. Verify signature of `trust_chain[1]` (`Network_Delegated_Statement`).
   - **Step 2c (App Configuration)**: Extract `jwks_uri` from `trust_chain[1]`. Retrieve public key from `jwks_uri` (`https://bpbuddy.example.com/.well-known/jwks.json`). Verify signature of `trust_chain[0]` (`App_EC`).

3. **Verification of CMS Base Attestation**:
   - The Data Holder verifies CMS app standing via the transitive `extensions.cms_app` embedded inside `trust_chain[1]` (`Network_Delegated_Statement`).
   - *Optional Fetch*: Data Holders MAY fetch the original `CMS_App_Statement` directly from CMS via `GET https://library.cms.gov/fetch?sub=https%3A%2F%2Flibrary.medicare.gov%2Fapps%2Fbpbuddy`.

4. **Date, Nonce & Expiration Validation**:
   - Confirm `iat <= current_time` and `exp > current_time` for all 3 statements.
   - Confirm `exp - iat` does not exceed maximum permitted thresholds.

5. **Policy & Constraint Enforcement**:
   - Verify `metadata_policy` in `trust_chain[1]`. Ensure requested `grant_types` (`authorization_code`, `refresh_token`, `token-exchange`, `client_credentials`) and `scope` satisfy `"subset_of"` constraints.
   - Confirm `constraints` in `trust_chain[2]` permit `allowed_entity_types` containing `openid_relying_party` for `trust_chain[0]`.

6. **Proof of Key Possession Verification**:
   - Extract public key from the app's verified `jwks_uri`.
   - Verify signature of `client_assertion` JWT using key matching `kid`.
   - Confirm `client_assertion` claims (`iss`, `sub`, `aud`, `exp`, `jti`).

7. **Dual-Gate Instant Revocation Check**:
   - Read `extensions.cms_app.status_list` in `trust_chain[1]`.
   - Verify bit index `4092` against local 60-minute cached RFC 9493 Bitstring Status List (`https://library.medicare.gov/.well-known/status-list.json`). Reject if bit `4092 == 1` (Revoked by CMS).

8. **Client Registration & Record Creation**:
   - Save persistent client record in database (`client_id`, verified `redirect_uris`, `scope`, verified App JWK).
   - Respond with `HTTP 201 Created` containing server-assigned `client_id`.

---

## Zero-Downtime Key Rotation Mechanisms

OpenID Federation 1.0 supports seamless, zero-downtime key rotation across all three architectural tiers without requiring service suspension or manual re-registration:

### Client Application Key Rotation
* **App-Hosted JWKS Update**: The Client Application generates a new key pair (`bpbuddy-app-key-02`) and appends the public key to its hosted JWKS (`https://bpbuddy.example.com/.well-known/jwks.json`) alongside the existing key (`bpbuddy-app-key-01`).
* **Instant Verification**: When the app signs `client_assertion` or `App_EC` with `bpbuddy-app-key-02`, Data Holders match the `kid` header parameter against the app's `jwks_uri`. If the `kid` is new, Data Holders dereference `https://bpbuddy.example.com/.well-known/jwks.json` to refresh their cached key store.
* **Deprecation**: Once inflight tokens expire, the app removes `bpbuddy-app-key-01` from its `jwks.json`. No updates to `CMS_App_Statement` or `Network_Delegated_Statement` are required.

### Home Network Authority Key Rotation
* **Multi-Key Statement**: The CMS Trust Anchor issues `CMS_Network_Statement` containing Home Network A's active public keys in a multi-key `jwks` array (`[network-a-key-2026, network-a-key-2027]`).
* **Seamless Transition**: Home Network A begins signing `Network_Delegated_Statement` with `network-a-key-2027`. Data Holders evaluate `trust_chain[1]` signatures against `trust_chain[2].jwks` by matching `kid: "network-a-key-2027"`.

### CMS Root Trust Anchor Key Rotation
* **Root JWKS Publication**: CMS publishes its Root JWKS at `https://library.cms.gov/.well-known/openid-federation`.
* **Out-of-Band Trust Updates**: CMS appends new Root Signing Keys to its published Root JWKS before issuing new network statements. Data Holders periodically refresh their local CMS Root JWKS store to verify incoming trust chains.

---

## Architectural Comparison Matrix

| Feature | Direct Web PKI Model (`registration.html`) | OpenID Federation Model (`registration-openid-federation.html`) |
| :--- | :--- | :--- |
| **Trust Anchor** | CMS App Library JWKS URL | CMS OpenID Federation Trust Anchor (`https://library.cms.gov`) |
| **Accreditation Proofs** | Single CMS Software Statement | **Sequential Delegation**: CMS App Base -> Network-Delegated Statement |
| **App Public Key Host** | App-Hosted `jwks_uri` (or CMS Fallback) | **App-Hosted `jwks_uri`** (verified in `CMS_App_Statement`) |
| **Registration Flow** | Explicit `POST /register` | **Explicit `POST /register`** (Automatic Registration Out of Scope) |
| **Trust Chain Structure** | 1-Tier Flat Software Statement | **3-Tier Linear Chain** (`App -> Home Network -> CMS Anchor`) |
| **PKI / ASN.1 Dependency** | None (JSON-native) | **None (100% JSON & JOSE Native)** |

---

> [!NOTE]
> **TODO**: Outline conformance requirements for signaling via `.well-known` files that a Data Holder supports this dynamic registration workflow (e.g. `/.well-known/smart-configuration` updates).


