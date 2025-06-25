## 🧠 Formula CPU Risk Analyzer for Salesforce

This Salesforce Lightning Web Component (LWC) helps developers and admins proactively detect **complex formula fields** that may risk hitting **Apex CPU time limits**. It analyzes all formula fields on a specific object and calculates their:


| 🔍 Metric                         | 🧠 Meaning                                                                                                              |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 🧬 **Nesting depth**              | How deep the formula nesting is (e.g., nested `IF`, `AND`, `OR` logic). Deep nesting can hit CPU limits.                |
| 🔗 **Cross-object hops**          | How many relationships the formula travels across (`Account.Owner.Profile.Name` = 2 hops). More hops = more CPU.        |
| 🧠 **Heavy function count**       | Count of expensive functions like `ISCHANGED`, `PRIORVALUE`, `VLOOKUP`, `GEOLOCATION`, `DISTANCE`. These are CPU-heavy. |
| 🔥 **CPU risk level**             | Based on depth, hops, heavy functions, length, and unbalanced parentheses. (High / Medium / Low).                       |
| 💣 **Formula too long**           | Boolean flag if formula exceeds 3000 characters. Can impact performance.                                                |
| 🧍 **Uses \$User / \$RecordType** | Checks if formula references current user or record type — often used in dynamic formulas.                              |
| 📈 **CPU Score**                  | A numerical score derived from multiple factors to quantify complexity/risk.                                            |
| 🚩 **Red Flags**                  | Text field highlighting specific issues found, e.g., “Excessive nesting”, “Unbalanced parentheses”, etc.                |

It uses the **Tooling API** securely via a **Named Credential**, removing the need for manual token management.

---

## 💼 Why It Matters
Salesforce formulas can silently contribute to performance bottlenecks, especially when:

🧬 Nesting gets deep
Deeply nested IF, AND, or CASE statements increase evaluation complexity.

🔗 Cross-object references are chained
Referencing multiple parent objects (e.g., Opportunity.Account.Owner.Profile.Name) increases data traversal and CPU usage.

🔁 Used in multiple automations
When the same formula field is used in multiple Flows, validation rules, or process builders, it's recalculated multiple times.

🧠 Contain heavy functions
Expensive functions like VLOOKUP, ISCHANGED, PRIORVALUE, DISTANCE, GEOLOCATION can cause spikes in CPU time.

🕵️ Used in record-triggered Flows or Apex
When formulas are accessed via triggers or flows, Salesforce recalculates them, impacting total transaction time.

🧮 Used in List Views or Reports
Formula fields on frequently-used list views or report filters slow down loading and query times.

🧱 Include hardcoded logic or IDs
Makes formulas brittle and harder to maintain, often leading to downstream logic errors or misfires.

🔁 Have repeated expressions
Repeating the same logic multiple times within a formula increases processing cost unnecessarily.

📅 Use date/time logic excessively
Functions like NOW(), TODAY(), DATEVALUE() can recalculate on every view/load, increasing overhead.

🧾 Evaluated on large data volumes
In batch Apex or mass updates (e.g., data loads), formula fields contribute to CPU usage per record.

This tool surfaces those risks **before they become production incidents**.

---

## 🚀 Features

* Secure Tooling API access via **Named Credential**
* Lightweight LWC with **dynamic badge indicators**
* Easily extensible

---

## 🧩 Prerequisites

# How to Obtain an OpenAI API Key

To use the OpenAI API, you'll need to obtain an API key. Follow these steps to get your API key from OpenAI.

## Steps to Get Your OpenAI API Key

1. **Sign Up for an OpenAI Account:**
   - Visit the [OpenAI website](https://www.openai.com/).
   - Click on **Sign Up** or **Get Started** to create a new account.
   - Follow the prompts to complete the registration process.

2. **Log In to Your OpenAI Account:**
   - If you already have an account, click on **Log In** on the OpenAI website.
   - Enter your credentials and access your account dashboard.

3. **Navigate to the API Keys Section:**
   - Once logged in, go to the [OpenAI API Dashboard](https://platform.openai.com/account/api-keys).
   - You may be required to verify your email address or complete other security checks before accessing the API keys.

4. **Generate a New API Key:**
   - In the API Keys section, click on **Create New Key** or a similar option.
   - Provide a name or label for the key if prompted (e.g., "My Salesforce Integration").
   - Click **Generate** or **Create** to generate your API key.

5. **Copy Your API Key:**
   - Once generated, your new API key will be displayed on the screen.
   - Click the **Copy** button or manually copy the key to your clipboard.
   - Store this key securely, as it provides access to the OpenAI API.

6. **Use Your API Key:**
   - You can now use the API key in your applications or integrations to authenticate requests to the OpenAI API.

## Security Tips

- **Keep Your API Key Confidential:** Do not share your API key publicly or include it in client-side code.
- **Regenerate Keys if Compromised:** If you believe your API key has been compromised, regenerate it immediately from the OpenAI dashboard.
- **Monitor Usage:** Regularly check your OpenAI usage to ensure there are no unexpected activities.

By following these steps, you'll be able to obtain and securely use your OpenAI API key for accessing the OpenAI services.


## Adding Remote Site Settings for OpenAI API in Salesforce

To configure Salesforce to communicate with the OpenAI API, follow these steps to add a remote site setting.

## Steps to Add Remote Site Settings

1. **Log in to Salesforce:**
   - Go to your Salesforce instance and log in with an account that has administrative privileges.

2. **Navigate to Remote Site Settings:**
   - Click on the **Setup** icon (the gear icon) in the upper right corner.
   - In the quick find box, type `Remote Site Settings` and select it from the dropdown list.

3. **Create a New Remote Site:**
   - Click the **New Remote Site** button.

4. **Fill in the Remote Site Details:**
   - **Remote Site Name:** Enter a name for the remote site. Example: `OpenAI_API`.
   - **Remote Site URL:** Enter `https://api.openai.com`.
     - Ensure you use `https://` for the secure protocol.
   - **Description:** Optionally, add a description such as `Remote site for OpenAI API`.

5. **Save the Remote Site:**
   - Click the **Save** button to create the remote site setting.

6. **Verify the Remote Site Setting:**
   - After saving, you should see the new remote site listed in the Remote Site Settings. You can click on the name to view or edit details if needed.

## Additional Tips

- **Security and Access:** Ensure that the remote site setting matches the OpenAI API URL exactly. The protocol (`https://`) and domain must be correct.
- **Testing Connectivity:** Use an HTTP request tool or write Apex code to test if Salesforce can access the OpenAI API.
- **Apex Integration:** Consider using named credentials for storing authentication securely and simplifying API calls.

By following these steps, you can configure Salesforce to communicate with the OpenAI API. Ensure that the URL and other details are accurate to avoid any issues.

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

1. Navigate to App(FormulaSniffR) Open the App Page (FormulaSniffR).
2. On load, the component:

   * Reads the `objectApiName` from the user.
   * Uses Tooling API to retrieve all formula fields for the selected object.
   * Displays risk indicators for each field

![image](https://github.com/user-attachments/assets/db0d893a-cded-4bc0-a932-e9c1e713616e)
![image](https://github.com/user-attachments/assets/df7aeef2-ae64-452a-99a1-93fe19ed9327)
![image](https://github.com/user-attachments/assets/26ad1c69-d5c3-4f41-bb6e-f6b35e935912)
![image](https://github.com/user-attachments/assets/4e257543-6c95-43bf-9f9e-966590cc1e80)

## 📅 Salesforce Compatibility

* API Version: `60.0` (Summer '24)
* Works with: Salesforce DX, Scratch Orgs, Sandboxes, Dev Orgs

---

## 🔐 Security
* No secrets (tokens or keys) are stored in this repo.
---
