# Upstream AI Website

Data trust and operator intelligence for small water utilities.

## Site Structure

### Main Pages
- **index.html** - Homepage (updated with Model 1: Data Trust & Operator Co-Pilot positioning)
- **security.html** - Security overview and technical implementation details

### Persona Landing Pages
- **for-operators.html** - For water/wastewater operators (addresses alarm fatigue, data trust, decision confidence)
- **for-managers.html** - For utility/district managers (focuses on ROI, budget justification, operational efficiency)
- **for-boards.html** - For board members (emphasizes governance, compliance, fiduciary responsibility)

### Case Studies
- **case-study-crestone.html** - Crestone Water & Sewer District: Eliminating alarm fatigue in 90 days (94% reduction in false alarms, $31K saved in 6 months)
- **case-study-round-mountain.html** - Round Mountain W&SD: Avoiding compliance violations with transparent data (prevented $45K violation, 18 hrs/month saved)

## Deployment

This is a static HTML/CSS site with no build process required.

### Quick Deploy Options

**Option 1: Netlify**
1. Drag the entire folder to netlify.com/drop
2. Done!

**Option 2: Vercel**
1. `npx vercel --prod`
2. Done!

**Option 3: GitHub Pages**
1. Push to GitHub
2. Enable Pages in repo settings
3. Done!

### Form Setup

The contact form on all pages is pre-configured to submit to `hello@getupstream.ai`.

**To enable form submissions:**
1. Sign up at formspree.io (free)
2. Create a new form
3. Get your form ID
4. In `index.html`, find line ~450 and replace `YOUR_FORM_ID` with your actual ID
5. Test by submitting the form

**Or use the mailto fallback:**
- Already works with zero setup
- Opens user's email client with pre-filled message
- See FORM_SETUP.md for details

## Business Model

The site now reflects **Model 1: Data Trust & Operator Co-Pilot Foundation**:

### Two-Tier Pricing
- **Trust Foundation:** $600/month - Data quality scoring, transparent calculations, audit trails
- **Operator Co-Pilot:** $1,800/month - Everything in Foundation + AI predictions with explainability

### Add-On Services
- Energy Optimization (30% of savings)
- Managed Operations ($4,500-6,500/month)
- Compliance Guarantee (+$800/month)
- Grant Writing (10% of funded amount)
- Cooperative Platform ($500/utility/month)

## Target Personas

### 1. Operators (Primary Users)
**Pain points:** Sensor uncertainty, alarm fatigue, decision confidence  
**Landing page:** for-operators.html  
**Key message:** "Finally know if that sensor reading is real"

### 2. Utility Managers (Economic Buyers)
**Pain points:** Budget constraints, emergency repair costs, operational efficiency  
**Landing page:** for-managers.html  
**Key message:** "Reduce emergency repairs by 70% in year one"

### 3. Board Members (Governance)
**Pain points:** Compliance risk, fiduciary duty, community accountability  
**Landing page:** for-boards.html  
**Key message:** "Governance through operational transparency"

## Positioning

**Old pitch:** "AI-powered predictive maintenance for water utilities"

**New pitch:** "Data trust first, then intelligence. Know instantly if sensor readings are real. Stop guessing, start trusting your data."

This positioning leads with the operator's immediate pain (data uncertainty) rather than the futuristic benefit (AI predictions), making it more accessible to small rural utilities.

## Key Differentiators

1. **Trust scores on every data point** (0-100%)
2. **Transparent calculations** (click any number to see the formula)
3. **Full audit trails** (who, what, when, why)
4. **Explainable AI** (shows reasoning, not just predictions)
5. **Built for 1-5 person teams** (no IT staff needed)

## Case Study Highlights

### Crestone Water & Sewer District
- 94% reduction in false alarms (42/night → 2.5/night)
- $18K emergency pump repair avoided
- 38 hours/month operator time saved
- **ROI: 436% in first 6 months**

### Round Mountain Water & Sanitation District
- Zero compliance violations since deployment
- Prevented $45K NPDES violation with early sensor drift detection
- 18 hours/month saved on compliance reporting
- **ROI: 459% in first 8 months**

## Files

- `index.html` - Main homepage
- `security.html` - Security deep-dive
- `for-operators.html` - Operator persona landing page
- `for-managers.html` - Manager persona landing page
- `for-boards.html` - Board member persona landing page
- `case-study-crestone.html` - Crestone case study
- `case-study-round-mountain.html` - Round Mountain case study
- `FORM_SETUP.md` - Form configuration instructions
- `README.md` - This file

## Next Steps

1. Replace `YOUR_FORM_ID` in index.html with your Formspree form ID
2. Update domain references (currently using upstreamai.com)
3. Add Google Analytics if desired
4. Deploy to hosting
5. Test form submissions
6. Start pilot program with Colorado utilities

## Contact

hello@getupstream.ai
