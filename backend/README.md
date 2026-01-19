# 🇲🇺 FixMo Backend API

> Node.js + Express backend for FixMo civic reporting system

## 🚀 Overview

The FixMo Backend API handles report processing and email notifications to municipalities when new civic issues are reported by citizens.

## ✨ Features

- **📝 Report Processing**: Create and manage civic reports
- **📧 Email Notifications**: Automatic notifications to municipalities
- **🗄️ Database Integration**: Connected to Supabase
- **🔗 API Endpoints**: RESTful API for mobile app integration

## 🛠️ Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: Supabase (PostgreSQL)
- **Email**: Nodemailer (Gmail/Mailgun ready)
- **CORS**: Cross-origin support for frontend

## 🏗️ API Endpoints

### Health Check
```
GET /health
```

### Create Report (from mobile app)
```
POST /create-report
Body: {
  title: string,
  description: string,
  category: string,
  municipality: string,
  latitude: number,
  longitude: number,
  address?: string,
  image_url?: string
}
```

### Notify Municipality
```
POST /notify-municipality
Body: { reportId: string }
```

### Get Reports by Municipality
```
GET /reports/:municipality?status=pending
```

## 🚀 Setup & Run

```bash
cd backend
npm install
npm run dev
```

Server runs on: `http://localhost:3001`

## 📧 Email Configuration

For production, set environment variables:
```
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
```

## 🎯 Integration

- **Mobile App**: Calls `/create-report` when user submits report
- **Admin Dashboard**: Uses Supabase directly for real-time updates
- **Email System**: Automatically notifies municipalities 