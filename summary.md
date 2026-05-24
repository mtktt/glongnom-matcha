# Glongnom Matcha Order Site — Codebase Summary

---

## Project Overview

Glongnom is a small matcha drink and rice bowl business run by MM. This is a web-based order form that lets customers browse the menu, customize their drink, add items to a cart, and submit their order. Orders are logged to a Google Sheet and an email notification is sent to the shop owner(s).

There is no user account system, no payment gateway, and no real-time order tracking. It is intentionally simple: a single-page order form backed by Google Sheets and Google Apps Script.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Plain HTML, CSS, Vanilla JavaScript — no frameworks |
| Backend | Google Apps Script (GAS) deployed as a Web App |
| Database | Google Sheets (3 sheets: Menu, Orders, Config) |
| Email | Gmail via MailApp in Google Apps Script |
| Hosting | Frontend is a static file — GitHub Pages, Netlify, or anywhere static |
| Assets | Local .jpg images in the /assets folder |

No Node.js, no Python, no npm. The entire backend runs inside Google's infrastructure for free.

---

## File Structure

```
Glongnom-order-site/
|-- index.html       # Entire frontend: HTML + CSS + JS in one file
|-- code.gs          # Google Apps Script backend (deployed on Google's servers)
|-- assets/          # Product images — one .jpg per menu item (22 total)
|   |-- banner.jpg
|   |-- matcha-latte.jpg
|   |-- ...
|-- summary.md       # This file
```

Important: code.gs does NOT run on your machine. It is deployed on Google's servers as a Web App via Google Apps Script. The local copy is just for reference and version control.

---

## Frontend

### Pages and Layout

Single page: index.html. It contains:

1. **Banner** — full-width image at the top (assets/banner.jpg)
2. **Top Bar** — instruction notice; doubles as a shop-closed alert banner
3. **Category Filter Buttons** — All / Matcha / Non-Matcha / Rice Bowl
4. **Menu Grid** — dynamically rendered product cards fetched from the backend
5. **Cart Panel** — sticky sidebar (desktop) showing cart items, total, customer info fields, and submit button
6. **Option Modal** — popup when clicking "Add to Cart"; lets the customer configure:
   - Matcha grade: Medium or High grade (+10 baht) — matcha items only
   - Sweetness: 0%, 25%, 50%, 100%, 150%
   - Matcha separation preference (in cup vs. poured in)
   - Ice separation preference (separate bag vs. ready to drink)
   - Sauce + rice add-ons (seaweed, miso soup, salad, +10 baht each) — rice items only
   - Quantity and per-item note

### Responsive Design

- Desktop (900px+): 2-column layout, sticky cart panel on the right
- Mobile (under 900px): single column, cart stacks below menu

### Styling

- Pastel pink and brown color scheme (#fbb2c9 background, #4b2e24 text)
- Frosted-glass effect on inputs using backdrop-filter: blur
- No external CSS frameworks — fully hand-coded

---

## Backend (code.gs / Google Apps Script)

### Google Sheet Structure

The script auto-creates these sheets on first run if they do not exist:

| Sheet | Purpose |
|---|---|
| Menu | Items: Active (bool), Name, Price, IsMatcha, ImageURL |
| Config | Key-value settings: SHOP_OPEN, CLOSE_MESSAGE, ENABLE_* toggles |
| Orders | One row per order line-item, plus analytics date columns |

### API Endpoints

Both endpoints share the same /exec URL. The HTTP method determines behavior.

**GET** — Called on page load. Returns menu items and settings as JSON.

**POST** — Called on order submission. Receives the full order object, saves each item as a row to the Orders sheet, then sends email notifications.

**OPTIONS** — Handles CORS preflight requests from the browser.

### CORS

Backend adds Access-Control-Allow-Origin: * to all responses. Required because the frontend and backend are on different domain origins.

### Email Notification

On every new order, sendOrderEmails() sends a plain-text formatted order summary to all addresses in SHOP_EMAILS. Currently hardcoded to two Gmail addresses inside code.gs.

### Analytics Columns

Each saved order row includes extra computed columns: date (yyyy-MM-dd), month (yyyy-MM), year (yyyy), and hour of day (HH). Useful for pivot tables and sales charts in Sheets.

---

## Data Flow: Step-by-Step

```
1. Customer opens index.html in browser

2. Browser fires GET request to the Apps Script /exec URL

3. Apps Script reads Menu sheet + Config sheet, returns JSON

4. Frontend renders the menu grid
   - If SHOP_OPEN is FALSE: shows closed banner, disables submit button

5. Customer clicks a category filter button
   JS filters the in-memory MENU array, re-renders the grid

6. Customer clicks "Add to Cart" on a menu item
   Option modal opens with fields relevant to that item type

7. Customer configures options and clicks "Confirm Add to Cart"
   - JS calculates price: base + matcha grade extra + rice add-on extras
   - Item pushed into in-memory cart array
   - Modal closes, cart panel updates

8. Customer fills LINE name, phone number, and delivery location

9. Customer clicks "Confirm Order"
   - JS validates all three required fields are non-empty
   - POST request sent to Apps Script with full order JSON
   - Submit button disabled, shows "Sending..."

10. Apps Script receives POST
    - saveOrder(): appends one row per line-item to Orders sheet
    - sendOrderEmails(): sends Gmail summary to shop owners

11. Frontend shows success alert, clears cart, re-enables submit button
```

---

## Current Limitations and Issues

### Bugs

- **mode: no-cors on POST hides backend errors from the frontend.** When fetch uses no-cors, the browser cannot read the response body. If the backend crashes or returns an error, the frontend still shows "Order submitted successfully!" The customer has no idea the order failed to save.

- **Item IDs are positional and unstable.** IDs are generated as "m" + rowIndex. If rows in the Menu sheet are reordered, IDs shift. Not a crash bug since there is no cart persistence, but it is fragile design.

- **No backend input validation.** LINE name, phone, and address are written directly to the sheet without sanitization or length limits.

- **Phone field accepts any non-empty string.** No format check — values like "aaa" pass through and end up in the Orders sheet.

### Security Gaps

- **CORS is fully open.** Any website can call your Apps Script endpoint and submit fake orders. Low risk at this scale, but bots could spam the Orders sheet and inbox.

- **No rate limiting.** Nothing prevents automated scripts from submitting hundreds of fake orders in a loop.

- **Shop owner emails are hardcoded in code.gs.** To change notification recipients you must edit the script and redeploy it.

### Missing Features

- No order confirmation or receipt shown to the customer — only a generic success alert. No reference number, no order summary screen.
- No customer-facing order status tracking.
- No payment integration — handled entirely offline (PromptPay or LINE Pay manually).
- Images break silently when a menu item is renamed in the sheet because the filename is derived from the item name.
- No loading state while the menu fetches — the grid shows as blank on slow connections with no spinner or feedback.
- Cart is not persisted — refreshing the page loses everything the customer had selected.

---

## Improvement Suggestions

### Quick Wins (Low effort — do these first)

1. **Add a loading spinner while the menu fetches.**
   Show a spinner or skeleton placeholder cards while the GET request runs. Prevents the blank-page confusion on slow connections. A simple CSS spinner added before fetch() and removed after the .then() is enough.

2. **Add image error fallback.**
   Add an onerror handler on each img element so broken images show a default placeholder:
   ```js
   img.onerror = () => { img.src = 'assets/default.jpg'; };
   ```
   Add one default.jpg image to the assets folder to complete this.

3. **Move shop owner emails to the Config sheet.**
   Add an OWNER_EMAILS row to the Config sheet. Read it in code.gs instead of hardcoding. Lets you update recipients without redeploying the script.

4. **Validate phone number format on submit.**
   Add a /^\d{9,10}$/.test(phone) check before the POST fires. One line of JS that keeps the Orders sheet clean.

5. **Show a formatted order summary on screen after successful submission.**
   Instead of just an alert, render the full order details (item names, quantities, total, timestamp) on the page. Reduces "did my order go through?" messages and gives customers confidence.

---

### Medium-Term (Moderate effort)

6. **Fix the POST fetch mode to enable real error feedback.**
   Remove mode: no-cors. Ensure Apps Script returns proper CORS headers on POST responses. This lets the frontend read the response body and show real error messages when the backend fails.

7. **Decouple image filenames from menu item names.**
   The ImageURL column already exists in the Menu sheet but the frontend ignores it. Add logic: if ImageURL is filled in the sheet, use it; otherwise fall back to the auto-generated slug. Lets you rename items freely without breaking images.

8. **Add a honeypot field for basic spam protection.**
   Add a hidden input that humans never fill but bots do. On the backend, reject any POST where that field has a value. No CAPTCHA needed — cheap and effective at this scale.

9. **Persist customer info in localStorage.**
   Save LINE name, phone, and address to localStorage after a successful order. Pre-fill those fields on the next visit. Small UX improvement that returning customers will appreciate.

10. **Show inactive items as sold out instead of hiding them.**
    When Active = FALSE, render the card grayed out with a "sold out" label instead of removing it. Keeps the full menu visible and builds anticipation when items return.

---

### Long-Term (Bigger effort)

11. **Build an admin panel using Apps Script custom menus.**
    Add a custom menu to the Google Spreadsheet UI that lets you toggle shop open/close, manage menu items, and view a daily order summary — without editing raw cells. Apps Script supports custom menus natively at no extra cost.

12. **Add Line Notify integration.**
    Replace or supplement email with a Line Notify message when a new order arrives. Uses the Line Notify API called via Apps Script UrlFetchApp. Far more practical than email for a food business in Thailand. The service is free.

13. **Add repeat order functionality via localStorage.**
    Store the last 1-3 orders in localStorage and show a "Reorder" button that pre-fills the cart. High perceived value for returning customers, relatively low engineering effort.

14. **Add payment slip upload.**
    After order submission, let customers upload their PromptPay transfer screenshot. Save it to Google Drive via Apps Script and store the file link in the Orders sheet row. Reduces manual payment confirmation work.

15. **Migrate backend if order volume grows significantly.**
    Apps Script has a 6-minute execution time limit and MailApp caps at 100 emails/day on free accounts. If the business scales, consider migrating to FastAPI (Python) or Next.js API routes with Supabase or Firebase for reliability and scale.



### Your Tasks
I want my agent team to create new frontend and backend from scratch using the same understanding and menu data with these improvements:
1. Create new google sheet as database with contain Admin Panel for me to customize everything about menus, option, shop open/close, close message.
2. Theme Styling: Pastel pink, Dark brown, and off white.
3. Add loading spinner.
4. Validate phone number format on submit.
5. Show a formatted order summary on screen after successful submission.
6. Fix the POST fetch mode to enable real error feedback.
7. Add a honeypot field for basic spam protection.
8. Persist customer info in localStorage.
9. Show inactive items as sold out instead of hiding them.
10. Change from email to Line Notify
11. UX/UI improvements: chip styles option, replaced raw banner-image dependency with a typographic hero that I can custom message, live total in modal.
12. Language change mode TH/EN button for user.