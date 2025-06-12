# 📅 Schedule App

> fully cursor-generated 
> A modern, minimalist calendar and task management application with real-time multi-user collaboration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Vue.js](https://img.shields.io/badge/Vue.js-3.x-4FC08D.svg?logo=vue.js)](https://vuejs.org/)
[![Flask](https://img.shields.io/badge/Flask-2.x-000000.svg?logo=flask)](https://flask.palletsprojects.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-3776AB.svg?logo=python)](https://www.python.org/)

## 🌟 Features

### 🤝 Multi-User Collaboration
- **Shared Calendar Views**: See all team members' schedules in real-time
- **Individual Control**: Manage only your own tasks and time blocks
- **Visual User Distinction**: Current user highlighted, others shown in muted colors
- **Real-time Updates**: Changes sync across all connected users instantly

### 📊 Smart Calendar Views
- **📅 Monthly View**: Overview of all users' daily work hours and task progress
- **📍 Weekly View**: Detailed hour-by-hour schedule with drag-and-drop time blocks
- **🎯 Daily View**: Focused single-day planning with hourly breakdown
- **🎨 Progress Visualization**: Color-coded progress indicators and visual feedback

### ⏰ Time Management
- **📝 Time Stickers**: 12 draggable 1-hour work blocks per week
- **🖱️ Drag & Drop Scheduling**: Intuitive time block placement
- **📋 Task Tracking**: Create and monitor task progress with visual indicators
- **🎨 Smart Color Coding**: Automatic progress-based color assignments

### 🔐 Security & Authentication
- **👤 User Authentication**: Secure login/register system
- **🛡️ Session Management**: Secure session handling
- **🔒 Data Privacy**: Users can only modify their own data

## 🚀 Quick Start

### One-Click Deployment (Recommended)

For Linux servers:

```bash
# Clone the repository
git clone https://github.com/yourusername/schedule-app.git
cd schedule-app

# Make deployment script executable
chmod +x deploy.sh

# Deploy with test data (development)
./deploy.sh

# OR deploy for production (no test data)
./deploy.sh --production
```

The deployment script will automatically:
- ✅ Install all dependencies (Python, Node.js, Nginx)
- ✅ Set up the backend with systemd service
- ✅ Build and configure the frontend
- ✅ Configure Nginx reverse proxy
- ✅ Create test users (development mode only)
- ✅ Start all services

### Manual Development Setup

#### Prerequisites
- Python 3.8+ 
- Node.js 16+
- npm

#### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r ../requirements.txt
python app.py
```
Backend runs on `http://localhost:5001`

#### Frontend Setup
```bash
cd frontend
npm install
npm run dev
```
Frontend runs on `http://localhost:3000`

## 🧪 Testing Multi-User Features

### Quick Demo Setup

1. **Generate test users**:
   ```bash
   python test_multi_user.py
   ```
   
   Creates 4 demo users with sample data:
   - 👩‍💻 `alice / password123` - Frontend Development
   - 👨‍💻 `bob / password123` - Backend Development  
   - 🎨 `charlie / password123` - UI/UX Design
   - 📊 `diana / password123` - Data Analysis

2. **Start the application**:
   ```bash
   # Terminal 1 - Backend
   cd backend && python app.py
   
   # Terminal 2 - Frontend  
   cd frontend && npm run dev
   ```

3. **Experience multi-user features**:
   - 🪟 Open multiple browser windows/tabs
   - 👤 Login with different test users
   - 📅 Check month view for all users' work hours
   - 🖱️ Try drag-and-drop (only your stickers are movable)
   - 🎨 Notice visual distinctions between users

### Expected Behavior
- **📅 Month View**: All users' daily hours displayed, current user in blue
- **📍 Week/Day Views**: 
  - ✅ Your stickers: Green with blue borders, draggable
  - 👥 Others' stickers: Gray, view-only
  - 🔄 Real-time updates across all users

## 🛠️ Tech Stack

| Component | Technology | Version |
|-----------|------------|---------|
| **Frontend** | Vue.js | 3.x |
| **Build Tool** | Vite | Latest |
| **HTTP Client** | Axios | Latest |
| **Backend** | Flask | 2.x |
| **Database** | SQLite | 3.x |
| **Web Server** | Nginx | Latest |
| **Process Manager** | Systemd | - |

## 📁 Project Structure

```
schedule-app/
├── 📁 backend/
│   ├── 🐍 app.py              # Flask API with multi-user support
│   └── 🗄️ schedule.db         # SQLite database (auto-created)
├── 📁 frontend/
│   ├── 📁 src/
│   │   ├── 📁 components/
│   │   │   ├── 🔐 LoginForm.vue    # Authentication UI
│   │   │   └── 📅 Calendar.vue     # Main calendar interface
│   │   ├── 📄 App.vue
│   │   └── 🚀 main.js
│   ├── 📄 index.html
│   ├── 📦 package.json
│   └── ⚙️ vite.config.js
├── 🐍 requirements.txt        # Python dependencies
├── 🚀 deploy.sh              # One-click deployment script
├── 🧪 test_multi_user.py     # Test data generator
├── 🚫 .gitignore
└── 📖 README.md
```

## 🔗 API Reference

### 🔐 Authentication
- `POST /api/register` - User registration
- `POST /api/login` - User authentication  
- `POST /api/logout` - Session termination
- `GET /api/user` - Current user information
- `PUT /api/user/task-name` - Update current task name

### 👥 Multi-User Data
- `GET /api/users/all` - All users (for shared views)
- `GET /api/daily-work-hours/all` - All users' daily hours (month view)
- `GET /api/time-stickers/all` - All users' scheduled time blocks

### 📋 Task Management
- `GET /api/tasks` - User's tasks for current month
- `POST /api/tasks` - Create new task
- `PUT /api/tasks/<id>/progress` - Update task progress

### ⏰ Time Stickers  
- `GET /api/time-stickers` - User's time stickers
- `POST /api/time-stickers` - Create week's time stickers
- `PUT /api/time-stickers/<id>` - Update sticker (content/schedule)

## 🗄️ Database Schema

<details>
<summary>Click to expand database structure</summary>

### Users Table
| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key |
| `username` | TEXT | Unique username |
| `password_hash` | TEXT | Hashed password |
| `current_task_name` | TEXT | Current project/task |

### Tasks Table
| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key |
| `user_id` | INTEGER | Foreign key to users |
| `title` | TEXT | Task title |
| `description` | TEXT | Task description |
| `date` | TEXT | Task date (YYYY-MM-DD) |
| `progress` | INTEGER | Progress (0-100) |

### Time Stickers Table
| Field | Type | Description |
|-------|------|-------------|
| `id` | INTEGER | Primary key |
| `user_id` | INTEGER | Foreign key to users |
| `content` | TEXT | Sticker content |
| `week_start` | TEXT | Week start date |
| `position_type` | TEXT | 'pending' or 'scheduled' |
| `scheduled_date` | TEXT | Scheduled date |
| `scheduled_time` | TEXT | Scheduled time (HH:MM) |
| `view_type` | TEXT | 'week' or 'day' |
| `is_expired` | BOOLEAN | Expiration flag |

</details>

## 🚀 Production Deployment

### System Requirements
- Ubuntu/Debian Linux server
- 1GB+ RAM
- 10GB+ disk space
- Internet connection

### Deployment Options

#### Option 1: Automated Deployment (Recommended)
```bash
git clone https://github.com/yourusername/schedule-app.git
cd schedule-app
chmod +x deploy.sh
./deploy.sh --production
```

#### Option 2: Docker Deployment (Coming Soon)
```bash
docker-compose up -d
```

#### Option 3: Manual Deployment
See [Manual Deployment Guide](docs/manual-deployment.md) for detailed instructions.

### Post-Deployment

After successful deployment:
- 🌐 Access your app at `http://your-server-ip`
- 📊 Monitor logs: `sudo journalctl -u schedule-app -f`
- 🔄 Restart backend: `sudo systemctl restart schedule-app`
- ⚙️ Reload Nginx: `sudo systemctl reload nginx`

## 📱 Mobile & Future Development

### Mobile Compatibility
- 📱 **Responsive Design**: Optimized for mobile browsers
- 💾 **PWA Ready**: Can be installed as a Progressive Web App
- 🔄 **Touch Optimized**: Drag-and-drop works on mobile devices

### Potential Extensions
- 📱 **Native Mobile Apps**: React Native or Flutter implementation
- 🔄 **Real-time Sync**: WebSocket-based live updates  
- 📊 **Analytics Dashboard**: Team productivity insights
- 🔗 **Calendar Integration**: Google Calendar, Outlook sync
- 🤖 **AI Suggestions**: Smart scheduling recommendations

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow
1. 🍴 Fork the repository
2. 🌟 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. 💫 Commit your changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to the branch (`git push origin feature/amazing-feature`)
5. 🎯 Open a Pull Request

### Issue Reporting
- 🐛 **Bug Reports**: Use the bug report template
- 💡 **Feature Requests**: Use the feature request template
- ❓ **Questions**: Check existing issues or start a discussion

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- 🎨 **Vue.js Community** for the amazing frontend framework
- 🐍 **Flask Community** for the lightweight backend framework
- 👥 **Contributors** who help improve this project
- 💡 **Open Source Community** for inspiration and resources

---

<div align="center">

**[⬆ Back to Top](#-schedule-app)**

Made with ❤️ by [Your Name](https://github.com/yourusername)

⭐ **If you find this project helpful, please give it a star!** ⭐

</div> 
