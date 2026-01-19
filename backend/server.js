const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Supabase configuration
const supabaseUrl = 'https://pdzyyxxqniessxycftuk.supabase.co';
const supabaseServiceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkenl5eHhxbmllc3N4eWNmdHVrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTg0MDMxNCwiZXhwIjoyMDY1NDE2MzE0fQ.N8DCw-V55-RvIrCpTQkRQq__uo_1gnB8cBjkbPKElcE';

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// Email configuration (using Gmail for demo - can be replaced with Mailgun)
const emailTransporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'fixmo.mauritius@gmail.com', // Demo email
    pass: process.env.EMAIL_PASS || 'demo_password' // In production, use app-specific password
  }
});

// Municipality email addresses
const municipalityEmails = {
  'Port Louis': 'portlouis@municipal.mu',
  'Curepipe': 'curepipe@municipal.mu',
  'Quatre Bornes': 'quatrebornes@municipal.mu',
  'Beau Bassin-Rose Hill': 'beaubassin@municipal.mu',
  'Vacoas-Phoenix': 'vacoas@municipal.mu',
  'Mahébourg': 'mahebourg@municipal.mu',
  'Flacq': 'flacq@municipal.mu',
  'Goodlands': 'goodlands@municipal.mu',
  'Triolet': 'triolet@municipal.mu',
  'Black River': 'blackriver@municipal.mu'
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'FixMo Backend API is running',
    timestamp: new Date().toISOString()
  });
});

// Endpoint to send email notification when new report is created
app.post('/notify-municipality', async (req, res) => {
  try {
    const { reportId } = req.body;

    if (!reportId) {
      return res.status(400).json({ error: 'Report ID is required' });
    }

    // Fetch report details from Supabase
    const { data: report, error } = await supabase
      .from('reports')
      .select('*')
      .eq('id', reportId)
      .single();

    if (error || !report) {
      return res.status(404).json({ error: 'Report not found' });
    }

    // Get municipality email
    const municipalityEmail = municipalityEmails[report.municipality];
    if (!municipalityEmail) {
      return res.status(400).json({ error: 'Municipality email not found' });
    }

    // Create email content based on roadmap example
    const emailSubject = `FixMo Report: ${report.category} in ${report.municipality}`;
    const emailBody = `
Hello,

A new civic issue was reported by a resident in your region via the FixMo app.

📍 Location: ${report.address || `${report.latitude}, ${report.longitude}`}
📂 Category: ${report.category}
📝 Title: ${report.title}
📄 Description: ${report.description}
📅 Date: ${new Date(report.created_at).toLocaleDateString()}

${report.image_url ? `📷 Photo: ${report.image_url}` : '📷 Photo: No image attached'}

Status: ${report.status.toUpperCase()}

Please manage this via the FixMo admin dashboard:
👉 http://localhost:3000

Report ID: ${report.id}

Thank you for making Mauritius better!
FixMo Team 🇲🇺
    `;

    // Send email
    const mailOptions = {
      from: process.env.EMAIL_USER || 'fixmo.mauritius@gmail.com',
      to: municipalityEmail,
      subject: emailSubject,
      text: emailBody,
      html: emailBody.replace(/\n/g, '<br>')
    };

    // For demo purposes, log the email instead of sending
    console.log('\n📧 EMAIL NOTIFICATION:');
    console.log('To:', municipalityEmail);
    console.log('Subject:', emailSubject);
    console.log('Body:\n', emailBody);
    console.log('-------------------\n');

    // Uncomment below to actually send emails in production
    // await emailTransporter.sendMail(mailOptions);

    res.json({ 
      success: true, 
      message: 'Municipality notified successfully',
      municipalityEmail,
      reportId: report.id
    });

  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: 'Failed to send notification' });
  }
});

// Endpoint to process and create new report (called from mobile app)
app.post('/create-report', async (req, res) => {
  try {
    const reportData = req.body;

    // Validate required fields
    if (!reportData.title || !reportData.municipality || !reportData.latitude || !reportData.longitude) {
      return res.status(400).json({ 
        error: 'Missing required fields: title, municipality, latitude, longitude' 
      });
    }

    // Insert report into Supabase
    const { data: newReport, error } = await supabase
      .from('reports')
      .insert([{
        title: reportData.title,
        description: reportData.description || '',
        category: reportData.category || 'Other',
        municipality: reportData.municipality,
        latitude: reportData.latitude,
        longitude: reportData.longitude,
        address: reportData.address,
        image_url: reportData.image_url,
        status: 'pending'
      }])
      .select()
      .single();

    if (error) {
      console.error('Database error:', error);
      return res.status(500).json({ error: 'Failed to create report' });
    }

    // Send email notification to municipality
    try {
      await fetch(`http://localhost:${PORT}/notify-municipality`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reportId: newReport.id })
      });
    } catch (emailError) {
      console.error('Email notification failed:', emailError);
      // Continue even if email fails
    }

    res.status(201).json({
      success: true,
      message: 'Report created successfully',
      report: newReport
    });

  } catch (error) {
    console.error('Error creating report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Endpoint to get reports for a municipality
app.get('/reports/:municipality', async (req, res) => {
  try {
    const { municipality } = req.params;
    const { status } = req.query;

    let query = supabase
      .from('reports')
      .select('*')
      .eq('municipality', municipality)
      .order('created_at', { ascending: false });

    if (status && status !== 'all') {
      query = query.eq('status', status);
    }

    const { data: reports, error } = await query;

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch reports' });
    }

    res.json({ reports });

  } catch (error) {
    console.error('Error fetching reports:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 FixMo Backend API running on http://localhost:${PORT}`);
  console.log(`📧 Email notifications configured for municipalities`);
  console.log(`🗄️ Connected to Supabase database`);
  console.log(`🇲🇺 Ready to serve Mauritius civic reports!\n`);
});

module.exports = app; 