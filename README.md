## 🧠 Formula CPU Risk Analyzer for Salesforce

This Salesforce Lightning Web Component (LWC) helps developers and admins proactively detect **complex formula fields** that may risk hitting **Apex CPU time limits**. It analyzes all formula fields on a specific object and calculates their:

* 🧬 **Nesting depth**
* 🔗 **Cross-object hops**
* 🔥 **CPU risk level** (High / Medium / Low)

It uses the **Tooling API** securely via a **Named Credential**, removing the need for manual token management.

---

## 💼 Why It Matters

Salesforce formulas can silently contribute to **performance issues**, especially when:

* Nesting gets deep
* Cross-object references are chained
* Multiple formulas are evaluated in record-triggered flows or batch jobs

This tool surfaces those risks **before they become production incidents**.

---

## 🚀 Features

* Secure Tooling API access via **Named Credential**
* Lightweight LWC with **dynamic badge indicators**
* Designed for **record pages only** (auto-resolves `objectApiName`)
* Easily extensible

---

## 🧩 Setup Instructions

### 🔑 STEP 1: Create a Connected App (One-Time Setup)

1. **Go to:**
   Setup → **App Manager** → **New Connected App**

2. **Fill in:**

   * **Name:** `ToolingAPI_ConnectedApp`
   * **API Name:** (auto-filled)
   * **Contact Email:** (your email)

3. ✅ **Enable OAuth Settings:**

   * ☑️ Enable OAuth Settings
   * **Callback URL:**
     `https://login.salesforce.com/services/oauth2/callback`
   * **Selected OAuth Scopes:**

     * `Access and manage your data (api)`
     * `Perform requests on your behalf at any time (refresh_token, offline_access)`
     * `Full access (full)`

4. Click **Save**.
   🔑 Note the **Consumer Key** and **Consumer Secret**

> ⏳ Wait 2–10 minutes for it to become available.

---

### 🌐 STEP 2: Create an Auth Provider

1. Go to:
   Setup → **Auth. Providers** → **New**

2. **Provider Type:** `Salesforce`

3. Fill:

   * **Name:** `Salesforce_Tooling_Auth`
   * **Consumer Key:** from Connected App
   * **Consumer Secret:** from Connected App
   * **Authorize Endpoint URL:**
     `https://login.salesforce.com/services/oauth2/authorize`
   * **Token Endpoint URL:**
     `https://login.salesforce.com/services/oauth2/token`

4. Click **Save**
   🔁 Note the **Callback URL** Salesforce generates (you’ll use it in the next step)

---

### 🔁 STEP 3: Update Connected App with Callback URL

1. Go back to:
   Setup → **App Manager** → Find your Connected App → **Edit**

2. Replace the **old Callback URL** with the one from the **Auth Provider** (`https://...force.com/.../services/authcallback/...`)

3. Save again.

---

### 📛 STEP 4: Create a Named Credential

1. Go to:
   Setup → **Named Credentials** → **New**

2. Fill:

| Field                             | Value                                                                        |
| --------------------------------- | ---------------------------------------------------------------------------- |
| **Label**                         | `ToolingAPI`                                                                 |
| **Name**                          | `ToolingAPI`                                                                 |
| **URL**                           | `https://yourInstance.salesforce.com` (e.g., `https://na123.salesforce.com`) |
| **Identity Type**                 | Named Principal                                                              |
| **Authentication Protocol**       | OAuth 2.0                                                                    |
| **Authentication Provider**       | `Salesforce_Tooling_Auth`                                                    |
| **Scope**                         | `full refresh_token offline_access`                                          |
| **Generate Authorization Header** | ☑️ Yes                                                                       |
| **Allow Callouts**                | ☑️ Yes                                                                       |

3. Click **Save** → then click **Authenticate** to complete the OAuth flow.

---

## 🖥️ Usage

1. Navigate to a **record page** (e.g., Account).
2. In **Lightning App Builder**, drag the `FormulaFieldRiskAnalyser` component onto the layout.
3. Activate the page.
4. On load, the component:

   * Reads the current `objectApiName`
   * Uses Tooling API to retrieve all formula fields
   * Displays risk indicators for each field

---

## 📌 Known Limitations

* Works only on **record pages**.
* Requires **Tooling API** access and permissions.
* OAuth must be re-authenticated if access token expires (handled by refresh\_token scope).

---

## 📅 Salesforce Compatibility

* API Version: `60.0` (Summer '24)
* Works with: Salesforce DX, Scratch Orgs, Sandboxes, Dev Orgs

---

## 🔐 Security

* No secrets (tokens or keys) are stored in this repo.
* Be sure to `.gitignore` any sensitive files:

  ```bash
  *.pem
  *.key
  .env
  ```

---
