# General Quests Store - Product & Technical Specification

## 1. Overview
The **General Quests Store** is an application designed to motivate kids through gamified educational and responsibility-based quests. Kids earn virtual coins by completing quests (such as academics, life skills, and chores) and can spend those coins on rewards defined by their parents in a customized digital store.

- **Kids** experience a fun, interactive platform where they complete tasks to earn rewards they actually want.
- **Parents** use a control panel to create quests, define coin values, manage the reward store, and approve completions/payouts.

## 2. Technology Stack
- **Frontend:** React (developed as a mobile-first responsive web application to accommodate kids using tablets/phones and parents on desktop/mobile).
- **Backend:** Python (handling complex logic, API routes, and future AI integrations).
- **Database & Services:** Firebase (used for Authentication, real-time Firestore database, and Cloud Storage for photo proof uploads).

## 3. User Roles and Flows (MVP Scope)

### Parent Role
**Main flows:**
- **Create & Manage:**
  - Define Quest Templates by category (e.g., School, Life Skills, Creativity, Health, Family Help).
  - Add and manage Rewards in the Store (e.g., physical items, experiences, digital purchases).
- **Set Rules:**
  - Define a monthly coin budget (mapping to real-world allowance/budget).
  - Set a conversion rate (e.g., 10 coins = $1 or 10 ILS).
- **Review & Approve:**
  - Review and approve quest completion submissions (verifying optional photo/text proof).
  - Approve or decline reward redemption requests.

### Kid Role
**Main flows:**
- **Browse Quests:**
  - View available quests, filtering by category, time required, or difficulty.
- **Accept & Complete:**
  - Start a quest, mark it as done, and optionally upload a photo or text answer as proof.
- **Earn & Track:**
  - View current coin balance, streaks, badges, and progress.
- **Shop in the Store:**
  - Browse available rewards and see prices.
  - Track progress towards specific rewards via a progress bar.
  - Request redemption of a reward (which deducts coins and notifies the parent for approval).

## 4. Quest & Reward Mechanics

### Quest Design
- **Categories:** Academic, Life/Finance, Creativity, Family/Responsibility.
- **Quest Structure:**
  - Title and Description
  - Category and Time Estimate (e.g., 5/15/30+ minutes)
  - Base Coin Reward
  - Required Proof Type (None, Text Answer, Photo, Multiple-choice).

### Reward Store
- **Categories of Rewards:** Small (e.g., small accessory), Medium (e.g., online order within budget), Large (e.g., shopping trip or larger item).
- **Reward Structure:**
  - Title and Description
  - Coin Cost
  - Type: Physical item, Digital purchase, Experience
  - Image URL

## 5. Application Screens

### Kid View (Mobile-Optimized)
1. **Home:** Current coin balance, level, active streak, "Continue your quest", and "New quests for today".
2. **Quests:** Tabbed list of quests (Recommended, School, Life Skills, Family). Quest cards show title, coins, time estimate, and category badge.
3. **Quest Detail:** Full description, steps, proof requirements. Buttons to "Start" and "Submit" with upload capabilities.
4. **Store:** Grid of rewards with images, names, and coin costs. Reward detail view with a "Redeem" button (if balance allows) and a progress bar.
5. **Profile:** Earned badges, completed quests history, and transaction history.

### Parent View (Dashboard)
1. **Dashboard:** Overview of monthly coin budget/spend, pending quest approvals, pending reward redemptions, and quick stats per child.
2. **Quest Manager:** List of active quest templates. Ability to "Add Quest" (defining type, difficulty, coins, proof).
3. **Reward Manager:** List of store items. Add/edit rewards, toggle active status, mark requested rewards as "delivered".
4. **Settings:** Coin-to-money mapping, monthly reset dates, and notification preferences.

## 6. Data Model

The database (Firebase Firestore) will consist of the following high-level collections:

- **Users**
  - `id`, `role` (parent/child), `name`, `age`, `parentId` (for kids to link to parent).
- **QuestTemplates**
  - `id`, `title`, `description`, `category`, `difficulty`, `estimatedMinutes`, `baseCoins`, `proofType`.
- **QuestInstances**
  - `id`, `questTemplateId`, `childId`, `status` (available / in-progress / submitted / approved / rejected), `proofData` (text or image URL), `earnedCoins`, `timestamps`.
- **Rewards**
  - `id`, `title`, `description`, `imageUrl`, `coinCost`, `type`, `active` (boolean).
- **Redemptions**
  - `id`, `rewardId`, `childId`, `status` (requested / approved / delivered / declined), `timestamps`.
- **Wallets**
  - `childId`, `balanceCoins`, `totalLifetimeCoins` (for leveling).

## 7. Basic Logic and Rules
- **Earning:** Coins are added to the Kid's Wallet only after a Parent approves the submitted `QuestInstance`.
- **Spending:** When a Kid requests a `Redemption`, the coins are immediately deducted/held from the Wallet. The Parent must approve and mark the reward as "delivered". If declined, coins are refunded.
- **Gamification:** Levels are calculated based on `totalLifetimeCoins`. Badges can be awarded based on specific completion milestones (e.g., first 10 school quests, 7-day streak).

## 8. Phase 2+: Agentic & AI Components
*(These features are explicitly excluded from the MVP and planned for future iterations)*

- **AI Quest Generator:** A tool for parents to input a topic (e.g., "fractions, age 12") and receive 2-3 auto-generated quest ideas with suggested coin values and descriptions.
- **AI Reward Recommender:** Suggests new rewards based on the kid's past redemptions and category preferences.
- **Educational Coach:** AI analyzes a kid's text submission for a quest and suggests a relevant follow-up question for the parent to ask offline to reinforce learning.
