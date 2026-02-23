# Form Setup Instructions for Upstream AI Website

The website now includes a professional modal form for "Request Early Access" CTAs.

## How It Works

When users click any "Request Early Access" or "Talk to us" button:
1. Modal popup appears with form
2. User fills out: Name, Email, Phone, Utility Name, Role, Connections, Message
3. Form submits to your email: **hello@getupstream.ai**
4. User sees success message
5. Modal closes after 5 seconds

## Setup Options

You have **3 options** for handling form submissions:

---

### **Option 1: Formspree (Recommended)** ✅

**Pros:** Clean, professional, free for 50 submissions/month, no code changes needed  
**Setup time:** 5 minutes

**Steps:**
1. Go to https://formspree.io
2. Sign up (free account)
3. Create a new form
4. Copy your form ID (looks like: `mrgvabcd`)
5. Open `index.html` and find this line (around line 450):
   ```html
   <form id="earlyAccessForm" action="https://formspree.io/f/YOUR_FORM_ID" method="POST">
   ```
6. Replace `YOUR_FORM_ID` with your actual form ID:
   ```html
   <form id="earlyAccessForm" action="https://formspree.io/f/mrgvabcd" method="POST">
   ```
7. Done! Test it by submitting the form.

**Result:** Form submissions go to your email (hello@getupstream.ai), stored in Formspree dashboard.

---

### **Option 2: Basin (Alternative)**

**Pros:** Similar to Formspree, 100 submissions/month free  
**Setup time:** 5 minutes

**Steps:**
1. Go to https://usebasin.com
2. Sign up, create form
3. Get your form endpoint URL
4. Replace the form action in `index.html` with Basin's URL

---

### **Option 3: mailto: Fallback (Already Configured)** ✅

**Pros:** Works immediately with ZERO setup, no account needed  
**Cons:** Less polished (opens email client instead of smooth submit)

**How it works:**
- If Formspree/Basin fails, the form automatically falls back to opening the user's email client
- Pre-fills email to: hello@getupstream.ai
- Subject: "Early Access Request - [Utility Name]"
- Body contains all form data

**This is already configured as a backup**, so the form will ALWAYS work even without Formspree.

---

## What Happens After Submission

**Formspree/Basin flow:**
1. User submits form
2. You receive email at hello@getupstream.ai with all form data
3. User sees success message: "Thanks for your interest! We'll reach out within 24 hours..."
4. Modal auto-closes after 5 seconds

**mailto: fallback flow:**
1. User submits form
2. Their email client opens with pre-filled message
3. They click "Send" from their email
4. You receive email at hello@getupstream.ai

---

## Form Fields Collected

1. **Name** (required)
2. **Email** (required)
3. **Phone** (optional)
4. **Utility Name** (required) — e.g., "Crestone Water & Sewer District"
5. **Role** (required) — Dropdown:
   - Operator
   - Operations Manager
   - Utility Manager / District Manager
   - Public Works Director
   - Board Member
   - Other
6. **Connections Served** (optional) — Dropdown:
   - < 500
   - 500 - 1,000
   - 1,000 - 2,500
   - 2,500 - 5,000
   - 5,000 - 10,000
   - \> 10,000
7. **Message** (optional) — "Tell us about your biggest operational challenge"

---

## Testing the Form

### **Test 1: Check modal opens**
1. Open `index.html` in a browser
2. Click any "Request early access" button
3. Modal should appear with form

### **Test 2: Check form validation**
1. Try submitting with empty required fields
2. Should show validation errors

### **Test 3: Check submission (once Formspree is set up)**
1. Fill out form completely
2. Click "Request Early Access"
3. Should see "Sending..." then success message
4. Check hello@getupstream.ai inbox for email

### **Test 4: Check mailto fallback**
1. Open browser DevTools > Console
2. Block formspree.io domain
3. Submit form
4. Should open email client with pre-filled message

---

## Customization

### **Change email address:**
Find all instances of `hello@getupstream.ai` in `index.html` and replace with your preferred email.

### **Change form fields:**
Edit the form HTML starting around line 455 in `index.html`. Add/remove fields as needed.

### **Change success message:**
Find `<div class="form-success">` around line 495 and edit the text.

### **Change modal styling:**
CSS for modal starts around line 240. Colors, sizing, animations all customizable.

---

## Recommended Next Steps

1. **Set up Formspree** (5 minutes)
   - Free account: https://formspree.io
   - Replace `YOUR_FORM_ID` in index.html

2. **Test the form** thoroughly
   - Submit a test request
   - Check email delivery
   - Test on mobile

3. **Set up email auto-responder** (optional)
   - Formspree Pro ($10/mo) has auto-reply feature
   - Or set up Gmail filter to auto-reply to form submissions

4. **Add to Google Sheets** (optional)
   - Formspree can forward to Google Sheets
   - Or use Zapier to connect Basin → Google Sheets
   - Track all early access requests in one place

---

## Support

If you have issues:
- Formspree support: help@formspree.io
- Basin support: hello@usebasin.com

The mailto: fallback ensures the form ALWAYS works, even without Formspree/Basin setup.
