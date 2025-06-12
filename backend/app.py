from flask import Flask, request, jsonify, session
from flask_cors import CORS
from datetime import datetime, timedelta
import sqlite3
import hashlib
import os
import calendar

app = Flask(__name__)
app.secret_key = 'your-secret-key-change-this'
CORS(app, supports_credentials=True)

DATABASE = 'schedule.db'

def init_db():
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    # Users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            current_task_name TEXT DEFAULT ''
        )
    ''')
    
    # Check if current_task_name column exists, if not add it
    cursor.execute("PRAGMA table_info(users)")
    columns = [column[1] for column in cursor.fetchall()]
    if 'current_task_name' not in columns:
        cursor.execute('ALTER TABLE users ADD COLUMN current_task_name TEXT DEFAULT ""')
    
    # Tasks table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            date DATE NOT NULL,
            progress INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Time stickers table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS time_stickers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            content TEXT DEFAULT '',
            week_start DATE NOT NULL,
            is_expired BOOLEAN DEFAULT FALSE,
            position_type TEXT CHECK(position_type IN ('pending', 'scheduled')) DEFAULT 'pending',
            scheduled_date DATE,
            scheduled_time TIME,
            view_type TEXT CHECK(view_type IN ('week', 'day')),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    conn.commit()
    conn.close()

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    try:
        cursor.execute('INSERT INTO users (username, password_hash) VALUES (?, ?)',
                      (username, hash_password(password)))
        conn.commit()
        user_id = cursor.lastrowid
        session['user_id'] = user_id
        return jsonify({'message': 'User created successfully', 'user_id': user_id})
    except sqlite3.IntegrityError:
        return jsonify({'error': 'Username already exists'}), 400
    finally:
        conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('SELECT id, password_hash FROM users WHERE username = ?', (username,))
    user = cursor.fetchone()
    conn.close()
    
    if user and user[1] == hash_password(password):
        session['user_id'] = user[0]
        return jsonify({'message': 'Login successful', 'user_id': user[0]})
    else:
        return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    session.pop('user_id', None)
    return jsonify({'message': 'Logged out successfully'})

@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    year = request.args.get('year', datetime.now().year, type=int)
    month = request.args.get('month', datetime.now().month, type=int)
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('''
        SELECT id, title, description, date, progress 
        FROM tasks 
        WHERE user_id = ? AND strftime('%Y', date) = ? AND strftime('%m', date) = ?
        ORDER BY date
    ''', (session['user_id'], str(year), str(month).zfill(2)))
    
    tasks = []
    for row in cursor.fetchall():
        tasks.append({
            'id': row[0],
            'title': row[1],
            'description': row[2],
            'date': row[3],
            'progress': row[4]
        })
    
    conn.close()
    return jsonify(tasks)

@app.route('/api/tasks', methods=['POST'])
def create_task():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    title = data.get('title')
    description = data.get('description', '')
    date = data.get('date')
    
    if not title or not date:
        return jsonify({'error': 'Title and date required'}), 400
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO tasks (user_id, title, description, date) 
        VALUES (?, ?, ?, ?)
    ''', (session['user_id'], title, description, date))
    conn.commit()
    task_id = cursor.lastrowid
    conn.close()
    
    return jsonify({'message': 'Task created', 'task_id': task_id})

@app.route('/api/tasks/<int:task_id>/progress', methods=['PUT'])
def update_progress(task_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    progress = data.get('progress', 0)
    progress = max(0, min(100, progress))  # Clamp between 0-100
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('''
        UPDATE tasks SET progress = ? 
        WHERE id = ? AND user_id = ?
    ''', (progress, task_id, session['user_id']))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Progress updated', 'progress': progress})

@app.route('/api/user', methods=['GET'])
def get_user():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('SELECT username, current_task_name FROM users WHERE id = ?', (session['user_id'],))
    user = cursor.fetchone()
    conn.close()
    
    return jsonify({
        'user_id': session['user_id'], 
        'authenticated': True,
        'username': user[0] if user else '',
        'current_task_name': user[1] if user and user[1] else ''
    })

@app.route('/api/users/all', methods=['GET'])
def get_all_users():
    """Get all users for multi-user calendar view"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('SELECT id, username, current_task_name FROM users ORDER BY username')
    users = []
    for row in cursor.fetchall():
        users.append({
            'id': row[0],
            'username': row[1],
            'current_task_name': row[2] or 'Work'
        })
    conn.close()
    
    return jsonify(users)

@app.route('/api/time-stickers/all', methods=['GET'])
def get_all_time_stickers():
    """Get time stickers for all users for shared calendar view"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    week_start = request.args.get('week_start')
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    if week_start:
        cursor.execute('''
            SELECT ts.id, ts.user_id, ts.content, ts.week_start, ts.is_expired, 
                   ts.position_type, ts.scheduled_date, ts.scheduled_time, ts.view_type,
                   u.username, u.current_task_name
            FROM time_stickers ts
            JOIN users u ON ts.user_id = u.id
            WHERE ts.week_start = ? AND ts.position_type = 'scheduled'
            ORDER BY u.username, ts.created_at
        ''', (week_start,))
    else:
        cursor.execute('''
            SELECT ts.id, ts.user_id, ts.content, ts.week_start, ts.is_expired, 
                   ts.position_type, ts.scheduled_date, ts.scheduled_time, ts.view_type,
                   u.username, u.current_task_name
            FROM time_stickers ts
            JOIN users u ON ts.user_id = u.id
            WHERE ts.position_type = 'scheduled'
            ORDER BY ts.week_start DESC, u.username, ts.created_at
        ''')
    
    stickers = []
    for row in cursor.fetchall():
        stickers.append({
            'id': row[0],
            'user_id': row[1],
            'content': row[2],
            'week_start': row[3],
            'is_expired': bool(row[4]),
            'position_type': row[5],
            'scheduled_date': row[6],
            'scheduled_time': row[7],
            'view_type': row[8],
            'username': row[9],
            'task_name': row[10] or 'Work'
        })
    
    conn.close()
    return jsonify(stickers)

@app.route('/api/daily-work-hours/all', methods=['GET'])
def get_all_daily_work_hours():
    """Get daily work hours for all users for month view"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    year = request.args.get('year', datetime.now().year, type=int)
    month = request.args.get('month', datetime.now().month, type=int)
    
    # Calculate month date range
    start_date = f"{year}-{month:02d}-01"
    if month == 12:
        end_date = f"{year + 1}-01-01"
    else:
        end_date = f"{year}-{month + 1:02d}-01"
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT ts.scheduled_date, ts.user_id, u.username, u.current_task_name,
               COUNT(*) as sticker_count
        FROM time_stickers ts
        JOIN users u ON ts.user_id = u.id
        WHERE ts.position_type = 'scheduled' 
          AND ts.scheduled_date >= ? 
          AND ts.scheduled_date < ?
        GROUP BY ts.scheduled_date, ts.user_id, u.username, u.current_task_name
        ORDER BY ts.scheduled_date, u.username
    ''', (start_date, end_date))
    
    daily_hours = {}
    for row in cursor.fetchall():
        date = row[0]
        user_id = row[1]
        username = row[2]
        task_name = row[3] or 'Work'
        sticker_count = row[4]
        
        if date not in daily_hours:
            daily_hours[date] = []
        
        daily_hours[date].append({
            'user_id': user_id,
            'username': username,
            'task_name': task_name,
            'hours': sticker_count,  # Each sticker represents 1 hour
            'minutes': 0,
            'display': f"{sticker_count}:00"
        })
    
    conn.close()
    return jsonify(daily_hours)

@app.route('/api/user/task-name', methods=['PUT'])
def update_task_name():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    task_name = data.get('task_name', '')
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute('UPDATE users SET current_task_name = ? WHERE id = ?', 
                  (task_name, session['user_id']))
    conn.commit()
    conn.close()
    
    return jsonify({'message': 'Task name updated', 'task_name': task_name})

@app.route('/api/time-stickers', methods=['GET'])
def get_time_stickers():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    week_start = request.args.get('week_start')
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    if week_start:
        cursor.execute('''
            SELECT id, content, week_start, is_expired, position_type, 
                   scheduled_date, scheduled_time, view_type
            FROM time_stickers 
            WHERE user_id = ? AND week_start = ?
            ORDER BY created_at
        ''', (session['user_id'], week_start))
    else:
        cursor.execute('''
            SELECT id, content, week_start, is_expired, position_type, 
                   scheduled_date, scheduled_time, view_type
            FROM time_stickers 
            WHERE user_id = ?
            ORDER BY week_start DESC, created_at
        ''', (session['user_id'],))
    
    stickers = []
    for row in cursor.fetchall():
        stickers.append({
            'id': row[0],
            'content': row[1],
            'week_start': row[2],
            'is_expired': bool(row[3]),
            'position_type': row[4],
            'scheduled_date': row[5],
            'scheduled_time': row[6],
            'view_type': row[7]
        })
    
    conn.close()
    return jsonify(stickers)

@app.route('/api/time-stickers', methods=['POST'])
def create_time_stickers():
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    week_start = data.get('week_start')
    count = data.get('count', 12)
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    # Check if stickers already exist for this week
    cursor.execute('SELECT COUNT(*) FROM time_stickers WHERE user_id = ? AND week_start = ?',
                  (session['user_id'], week_start))
    existing_count = cursor.fetchone()[0]
    
    if existing_count == 0:
        # Create new stickers for this week
        for i in range(count):
            cursor.execute('''
                INSERT INTO time_stickers (user_id, week_start) 
                VALUES (?, ?)
            ''', (session['user_id'], week_start))
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': f'Created {count} stickers for week {week_start}'})

@app.route('/api/time-stickers/<int:sticker_id>', methods=['PUT'])
def update_time_sticker(sticker_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    
    # Build update query dynamically based on provided fields
    updates = []
    values = []
    
    if 'content' in data:
        updates.append('content = ?')
        values.append(data['content'])
    
    if 'position_type' in data:
        updates.append('position_type = ?')
        values.append(data['position_type'])
    
    if 'scheduled_date' in data:
        updates.append('scheduled_date = ?')
        values.append(data['scheduled_date'])
    
    if 'scheduled_time' in data:
        updates.append('scheduled_time = ?')
        values.append(data['scheduled_time'])
    
    if 'view_type' in data:
        updates.append('view_type = ?')
        values.append(data['view_type'])
    
    if 'is_expired' in data:
        updates.append('is_expired = ?')
        values.append(data['is_expired'])
    
    if updates:
        values.append(sticker_id)
        values.append(session['user_id'])
        
        query = f"UPDATE time_stickers SET {', '.join(updates)} WHERE id = ? AND user_id = ?"
        cursor.execute(query, values)
        conn.commit()
    
    conn.close()
    
    return jsonify({'message': 'Sticker updated'})

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=5001) 