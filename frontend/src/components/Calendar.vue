<template>
  <div class="calendar-container">
    <!-- Header with Progress Bar and Task Name -->
    <div class="header">
      <div class="task-name-section">
        <div class="task-name-input" v-if="editingTaskName">
          <input 
            v-model="currentTaskName" 
            @blur="saveTaskName"
            @keyup.enter="saveTaskName"
            placeholder="Enter task name"
            ref="taskNameInput"
          />
        </div>
        <div v-else class="task-name-display" @click="editTaskName">
          {{ currentTaskName || 'Click to set task name' }}
        </div>
      </div>
      
      <div class="progress-section">
        <div class="progress-controls">
          <button @click="adjustProgress(-10)" class="progress-btn">-10</button>
          <button @click="adjustProgress(-5)" class="progress-btn">-5</button>
          <button @click="adjustProgress(-1)" class="progress-btn">-1</button>
          <div class="progress-bar-container">
            <div class="progress-bar">
              <div 
                class="progress-fill" 
                :style="{ width: overallProgress + '%' }"
              ></div>
            </div>
            <span class="progress-text">{{ Math.round(overallProgress) }}%</span>
          </div>
          <button @click="adjustProgress(1)" class="progress-btn">+1</button>
          <button @click="adjustProgress(5)" class="progress-btn">+5</button>
          <button @click="adjustProgress(10)" class="progress-btn">+10</button>
        </div>
      </div>
      
      <div class="header-controls">
        <div class="view-switcher">
          <button 
            @click="setViewType('month')" 
            :class="{ active: viewType === 'month' }"
            class="view-btn"
          >Month</button>
          <button 
            @click="setViewType('week')" 
            :class="{ active: viewType === 'week' }"
            class="view-btn"
          >Week</button>
          <button 
            @click="setViewType('day')" 
            :class="{ active: viewType === 'day' }"
            class="view-btn"
          >Day</button>
        </div>
        <button @click="logout" class="logout-btn">Logout</button>
      </div>
    </div>

    <div class="main-content">
      <!-- Left Sidebar - Time Stickers -->
      <div 
        v-if="viewType !== 'month'" 
        class="stickers-sidebar" 
        :style="{ width: sidebarWidth + 'px' }"
        @dragover="handleSidebarDragOver"
        @drop="handleSidebarDrop"
      >
        <div class="sidebar-header">
          <h3>Time Stickers</h3>
          <span class="sticker-count">{{ timeStickers.filter(s => s.position_type === 'pending').length }}/12</span>
        </div>
        <div class="stickers-grid">
                      <div 
              v-for="sticker in pendingStickers" 
              :key="sticker.id"
              class="time-sticker"
              :class="{ 
                expired: sticker.is_expired,
                scheduled: sticker.position_type === 'scheduled'
              }"
              :data-sticker-id="sticker.id"
              draggable="true"
              @dragstart="handleStickerDragStart($event, sticker)"
              @dragend="handleDragEnd"
              @dblclick="editSticker(sticker)"
            >
              <div class="sticker-content">{{ sticker.content || '📝' }}</div>
            </div>
        </div>
        <div class="sidebar-resizer" @mousedown="startResize"></div>
      </div>

      <!-- Main Calendar Area -->
      <div class="calendar-main">
        <!-- Calendar Navigation -->
        <div class="calendar-nav">
          <button @click="navigateTime(-1)">&lt;</button>
          <h2>{{ formatDateRange() }}</h2>
          <button @click="navigateTime(1)">&gt;</button>
        </div>

        <!-- Month View -->
        <div v-if="viewType === 'month'" class="month-view">
          <div class="calendar-grid">
            <div class="day-header" v-for="day in dayHeaders" :key="day">{{ day }}</div>
            
            <div 
              v-for="date in calendarDays" 
              :key="date.key"
              class="calendar-day"
              :class="{ 
                'other-month': !date.isCurrentMonth,
                'has-tasks': date.tasks.length > 0,
                'selected': selectedDate === date.dateString
              }"
              @click="selectDate(date)"
            >
              <span class="day-number">{{ date.day }}</span>
              
              <!-- Work hours display for all users -->
              <div v-if="getDailyWorkHours(date.dateString).users.length > 0" class="work-hours">
                <div 
                  v-for="userHour in getDailyWorkHours(date.dateString).users" 
                  :key="userHour.user_id"
                  class="user-work-hour"
                  :class="{ 'current-user': userHour.user_id === user?.user_id }"
                >
                  {{ userHour.username }}: {{ userHour.display }} on {{ userHour.task_name }}
                </div>
              </div>
              
              <div class="tasks-preview">
                <div 
                  v-for="task in date.tasks.slice(0, 3)" 
                  :key="task.id"
                  class="task-dot"
                  :style="{ backgroundColor: getProgressColor(task.progress) }"
                ></div>
              </div>
            </div>
          </div>
        </div>

        <!-- Week View -->
        <div v-if="viewType === 'week'" class="week-view">
          <div class="week-grid">
            <div class="time-column">
              <div class="time-header"></div>
              <div 
                v-for="hour in 24" 
                :key="hour" 
                class="time-slot"
              >
                {{ String(hour - 1).padStart(2, '0') }}:00
              </div>
            </div>
            
            <div 
              v-for="(day, index) in weekDays" 
              :key="index"
              class="day-column"
            >
              <div class="day-header">
                <div class="day-name">{{ getDayName(day) }}</div>
                <div class="day-date">{{ day.getDate() }}</div>
              </div>
              <div 
                class="day-timeline"
                @dragover="handleDragOver"
                @drop="handleDrop($event, day)"
              >
                <div 
                  v-for="hour in 24" 
                  :key="hour"
                  class="timeline-hour"
                  :data-hour="hour - 1"
                  :data-date="formatDate(day)"
                >
                  <!-- 5-minute intervals -->
                  <div 
                    v-for="interval in 12" 
                    :key="interval"
                    class="timeline-interval"
                    :data-minute="(interval - 1) * 5"
                  ></div>
                  
                  <!-- Scheduled stickers -->
                  <div 
                    v-for="sticker in getScheduledStickers(day, hour - 1)"
                    :key="sticker.id"
                    class="scheduled-sticker"
                    :class="{ 
                      'other-user-sticker': !sticker.isCurrentUser,
                      'current-user-sticker': sticker.isCurrentUser
                    }"
                    :data-sticker-id="sticker.id"
                    :draggable="sticker.isCurrentUser"
                    @dragstart="sticker.isCurrentUser ? handleStickerDragStart($event, sticker) : null"
                    @dragend="handleDragEnd"
                    @dblclick="sticker.isCurrentUser ? editSticker(sticker) : null"
                    :style="{ 
                      top: getStickerPosition(sticker),
                      zIndex: sticker.isCurrentUser ? 20 : 10
                    }"
                    :title="`${sticker.displayName}: ${sticker.content || '📝'}`"
                  >
                    <div class="sticker-user">{{ sticker.displayName }}</div>
                    <div class="sticker-content-text">{{ sticker.content || '📝' }}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Day View -->
        <div v-if="viewType === 'day'" class="day-view">
          <div class="day-timeline-horizontal">
            <div 
              v-for="hour in 24" 
              :key="hour"
              class="hour-block"
              @dragover="handleDragOver"
              @drop="handleDrop($event, selectedDateObj, hour - 1)"
            >
              <div class="hour-label">{{ String(hour - 1).padStart(2, '0') }}:00</div>
              <div class="hour-content">
                <!-- Scheduled stickers for this hour -->
                                  <div 
                    v-for="sticker in getScheduledStickers(selectedDateObj, hour - 1)"
                    :key="sticker.id"
                    class="scheduled-sticker-horizontal"
                    :class="{ 
                      'other-user-sticker': !sticker.isCurrentUser,
                      'current-user-sticker': sticker.isCurrentUser
                    }"
                    :data-sticker-id="sticker.id"
                    :draggable="sticker.isCurrentUser"
                    @dragstart="sticker.isCurrentUser ? handleStickerDragStart($event, sticker) : null"
                    @dragend="handleDragEnd"
                    @dblclick="sticker.isCurrentUser ? editSticker(sticker) : null"
                    :style="{ 
                      zIndex: sticker.isCurrentUser ? 20 : 10
                    }"
                    :title="`${sticker.displayName}: ${sticker.content || '📝'}`"
                  >
                    <div class="sticker-user">{{ sticker.displayName }}</div>
                    <div class="sticker-content-text">{{ sticker.content || '📝' }}</div>
                  </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Sticker Edit Modal -->
    <div v-if="editingSticker" class="modal-overlay" @click="closeEditModal">
      <div class="modal-content" @click.stop>
        <h3>Edit Time Sticker</h3>
        
        <!-- Content textarea -->
        <div class="form-field">
          <label>Content:</label>
          <textarea 
            v-model="editingStickerContent"
            placeholder="Enter sticker content..."
            rows="3"
            @keyup.esc="closeEditModal"
          ></textarea>
        </div>
        
        <!-- Schedule settings section -->
        <div class="schedule-section">
          <h4>{{ editingSticker.position_type === 'scheduled' ? 'Current Schedule' : 'Schedule Sticker' }}</h4>
          
          <!-- Date and time inputs -->
          <div class="form-field">
            <label>Date:</label>
            <input 
              type="date" 
              v-model="editingStickerDate"
              class="date-input"
            />
          </div>
          
          <div class="form-field">
            <label>Time:</label>
            <input 
              type="time" 
              v-model="editingStickerTime"
              class="time-input"
              step="300"
            />
          </div>
          
          <!-- Action buttons based on current state -->
          <div class="form-field">
            <button 
              v-if="editingSticker.position_type === 'pending'" 
              @click="scheduleSticker" 
              class="schedule-btn"
              :disabled="!editingStickerDate || !editingStickerTime"
            >
              Schedule for {{ editingStickerDate }} {{ editingStickerTime }}
            </button>
            
            <button 
              v-if="editingSticker.position_type === 'scheduled'" 
              @click="moveToPending" 
              class="move-btn"
            >
              Move to Pending Area
            </button>
          </div>
        </div>
        
        <div class="modal-actions">
          <button @click="saveStickerContent" class="save-btn">Save</button>
          <button @click="closeEditModal" class="cancel-btn">Cancel</button>
        </div>
            </div>
    </div>

    <!-- Drag Ghost -->
    <div 
      v-if="dragGhost.visible" 
      class="drag-ghost"
      :style="dragGhost.style"
    >
      <div class="ghost-time">{{ dragGhost.timeInfo }}</div>
      <div class="ghost-content">{{ draggedSticker?.content || '📝' }}</div>
    </div>

  </div>
</template>

<script>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import axios from 'axios'

export default {
  name: 'Calendar',
  emits: ['logout'],
  setup(props, { emit }) {
    // Basic state
    const currentDate = ref(new Date())
    const currentYear = ref(currentDate.value.getFullYear())
    const currentMonth = ref(currentDate.value.getMonth())
    const selectedDate = ref('')
    const viewType = ref('month')
    const tasks = ref([])
    const timeStickers = ref([])
    const allTimeStickers = ref([]) // All users' time stickers
    const allUsers = ref([]) // All users data
    const allDailyHours = ref({}) // All users' daily work hours
    const user = ref(null) // Current user info
    
    // Task name state
    const currentTaskName = ref('')
    const editingTaskName = ref(false)
    const taskNameInput = ref(null)
    
    // Sidebar state
    const sidebarWidth = ref(250)
    const resizing = ref(false)
    
    // Sticker editing state
    const editingSticker = ref(null)
    const editingStickerContent = ref('')
    const editingStickerDate = ref('')
    const editingStickerTime = ref('')
    
    // Drag state
    const dragGhost = ref({
      visible: false,
      style: {},
      timeInfo: ''
    })
    const draggedSticker = ref(null)
    const dragPosition = ref({ date: null, hour: 0, minute: 0 })

    const dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ]

    // Computed properties
    const monthName = computed(() => monthNames[currentMonth.value])
    
    const selectedDateObj = computed(() => {
      return selectedDate.value ? new Date(selectedDate.value) : new Date()
    })

    const weekDays = computed(() => {
      const date = viewType.value === 'week' 
        ? selectedDateObj.value 
        : new Date(currentYear.value, currentMonth.value, 1)
      
      const startOfWeek = new Date(date)
      const dayOfWeek = startOfWeek.getDay()
      const diff = startOfWeek.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1) // Monday start
      startOfWeek.setDate(diff)
      
      const days = []
      for (let i = 0; i < 7; i++) {
        const currentDay = new Date(startOfWeek)
        currentDay.setDate(startOfWeek.getDate() + i)
        days.push(currentDay)
      }
      return days
    })

    const pendingStickers = computed(() => {
      // Show all stickers in sidebar, but scheduled ones will be hidden by CSS
      return timeStickers.value
    })

    const overallProgress = computed(() => {
      if (tasks.value.length === 0) return 0
      const totalProgress = tasks.value.reduce((sum, task) => sum + task.progress, 0)
      return totalProgress / tasks.value.length
    })

    const calendarDays = computed(() => {
      const firstDay = new Date(currentYear.value, currentMonth.value, 1)
      const lastDay = new Date(currentYear.value, currentMonth.value + 1, 0)
      const startDate = new Date(firstDay)
      startDate.setDate(startDate.getDate() - firstDay.getDay())
      
      const days = []
      for (let i = 0; i < 42; i++) {
        const date = new Date(startDate)
        date.setDate(startDate.getDate() + i)
        
        const dateString = date.toISOString().split('T')[0]
        const isCurrentMonth = date.getMonth() === currentMonth.value
        
        days.push({
          day: date.getDate(),
          dateString,
          isCurrentMonth,
          key: dateString,
          tasks: tasks.value.filter(task => task.date === dateString)
        })
      }
      
      return days
    })

    // Utility functions
    const formatDate = (date) => {
      return date.toISOString().split('T')[0]
    }

    const formatDateRange = () => {
      if (viewType.value === 'month') {
        return `${monthName.value} ${currentYear.value}`
      } else if (viewType.value === 'week') {
        const start = weekDays.value[0]
        const end = weekDays.value[6]
        return `${start.toLocaleDateString()} - ${end.toLocaleDateString()}`
      } else {
        return selectedDateObj.value.toLocaleDateString('en-US', { 
          weekday: 'long', 
          year: 'numeric', 
          month: 'long', 
          day: 'numeric' 
        })
      }
    }

    const getDayName = (date) => {
      return date.toLocaleDateString('en-US', { weekday: 'short' })
    }

    const getProgressColor = (progress) => {
      if (progress < 30) return '#ff3b30'
      if (progress < 70) return '#ff9500'
      return '#34c759'
    }

    const getWeekStart = (date = new Date()) => {
      const d = new Date(date)
      const day = d.getDay()
      const diff = d.getDate() - day + (day === 0 ? -6 : 1) // Monday start
      return new Date(d.setDate(diff)).toISOString().split('T')[0]
    }

    // API functions
    const loadUserInfo = async () => {
      try {
        const response = await axios.get('/api/user')
        user.value = response.data
        currentTaskName.value = response.data.current_task_name || ''
      } catch (error) {
        console.error('Failed to load user info:', error)
      }
    }

    const loadAllUsers = async () => {
      try {
        const response = await axios.get('/api/users/all')
        allUsers.value = response.data
      } catch (error) {
        console.error('Failed to load all users:', error)
      }
    }

    const loadAllDailyHours = async () => {
      try {
        const response = await axios.get('/api/daily-work-hours/all', {
          params: {
            year: currentYear.value,
            month: currentMonth.value + 1
          }
        })
        allDailyHours.value = response.data
      } catch (error) {
        console.error('Failed to load all daily hours:', error)
      }
    }

    const loadAllTimeStickers = async () => {
      try {
        const weekStart = getWeekStart(selectedDateObj.value)
        const response = await axios.get('/api/time-stickers/all', {
          params: { week_start: weekStart }
        })
        allTimeStickers.value = response.data
      } catch (error) {
        console.error('Failed to load all time stickers:', error)
      }
    }

    const loadTasks = async () => {
      try {
        const response = await axios.get('/api/tasks', {
          params: {
            year: currentYear.value,
            month: currentMonth.value + 1
          }
        })
        tasks.value = response.data
      } catch (error) {
        console.error('Failed to load tasks:', error)
      }
    }

    const loadTimeStickers = async () => {
      try {
        const weekStart = getWeekStart(selectedDateObj.value)
        const response = await axios.get('/api/time-stickers', {
          params: { week_start: weekStart }
        })
        timeStickers.value = response.data
        
        // Create stickers for current week if none exist
        if (response.data.length === 0) {
          await axios.post('/api/time-stickers', {
            week_start: weekStart,
            count: 12
          })
          // Reload after creation
          const newResponse = await axios.get('/api/time-stickers', {
            params: { week_start: weekStart }
          })
          timeStickers.value = newResponse.data
        }
      } catch (error) {
        console.error('Failed to load time stickers:', error)
      }
    }

    const updateTaskName = async () => {
      try {
        await axios.put('/api/user/task-name', {
          task_name: currentTaskName.value
        })
      } catch (error) {
        console.error('Failed to update task name:', error)
      }
    }

    const getScheduledStickers = (date, hour) => {
      const dateStr = formatDate(date)
      
      // Get current user's stickers from timeStickers (for sidebar display)
      const currentUserStickers = timeStickers.value.filter(sticker => {
        if (sticker.position_type !== 'scheduled' || sticker.scheduled_date !== dateStr) {
          return false
        }
        
        if (!sticker.scheduled_time) return false
        
        const [stickerHour] = sticker.scheduled_time.split(':').map(Number)
        return stickerHour === hour
      })

      // Get all users' stickers from allTimeStickers (for calendar display)
      const allUsersStickers = allTimeStickers.value.filter(sticker => {
        if (sticker.position_type !== 'scheduled' || sticker.scheduled_date !== dateStr) {
          return false
        }
        
        if (!sticker.scheduled_time) return false
        
        const [stickerHour] = sticker.scheduled_time.split(':').map(Number)
        return stickerHour === hour
      })

      // Combine and mark current user's stickers
      const allStickers = [...currentUserStickers, ...allUsersStickers.filter(s => s.user_id !== user.value?.user_id)]
      
      return allStickers.map(sticker => ({
        ...sticker,
        isCurrentUser: sticker.user_id === user.value?.user_id || !sticker.user_id,
        displayName: sticker.username || user.value?.username || 'User'
      }))
    }

    const getStickerPosition = (sticker) => {
      if (!sticker.scheduled_time) return '0px'
      
      const [hour, minute] = sticker.scheduled_time.split(':').map(Number)
      const minutePosition = (minute / 60) * 60 // 60px per hour
      return minutePosition + 'px'
    }

    const getDailyWorkHours = (dateString) => {
      // Get all users' work hours for this date
      const usersHours = allDailyHours.value[dateString] || []
      
      if (usersHours.length === 0) return { users: [], display: '' }
      
      return {
        users: usersHours,
        display: usersHours.map(userHour => 
          `${userHour.username}: ${userHour.display} on ${userHour.task_name}`
        ).join('; ')
      }
    }

    // Event handlers
    const setViewType = (type) => {
      viewType.value = type
      if (type !== 'month') {
        loadTimeStickers()
        loadAllTimeStickers()
      } else {
        loadAllDailyHours()
      }
    }

    const navigateTime = (direction) => {
      if (viewType.value === 'month') {
        if (direction > 0) {
          if (currentMonth.value === 11) {
            currentMonth.value = 0
            currentYear.value++
          } else {
            currentMonth.value++
          }
        } else {
          if (currentMonth.value === 0) {
            currentMonth.value = 11
            currentYear.value--
          } else {
            currentMonth.value--
          }
        }
      } else if (viewType.value === 'week') {
        const newDate = new Date(selectedDateObj.value)
        newDate.setDate(newDate.getDate() + (direction * 7))
        selectedDate.value = formatDate(newDate)
      } else if (viewType.value === 'day') {
        const newDate = new Date(selectedDateObj.value)
        newDate.setDate(newDate.getDate() + direction)
        selectedDate.value = formatDate(newDate)
      }
    }

    const selectDate = (date) => {
      if (date.isCurrentMonth) {
        selectedDate.value = date.dateString
      }
    }

    const adjustProgress = async (delta) => {
      try {
        let targetTasks = []
        
        if (viewType.value === 'month') {
          targetTasks = tasks.value
        } else {
          targetTasks = tasks.value.filter(task => task.date === selectedDate.value)
        }
        
        // If no tasks exist, create a default task for the current date
        if (targetTasks.length === 0) {
          let taskDate
          if (viewType.value === 'month') {
            // For month view, use today's date
            taskDate = new Date().toISOString().split('T')[0]
          } else {
            // For week/day view, use selected date
            taskDate = selectedDate.value
          }
          
          if (!taskDate) return
          
          try {
            await axios.post('/api/tasks', {
              title: currentTaskName.value || 'Daily Task',
              description: 'Auto-created task for progress tracking',
              date: taskDate
            })
            
            // Reload tasks after creation
            await loadTasks()
            
            // Update target tasks
            if (viewType.value === 'month') {
              targetTasks = tasks.value
            } else {
              targetTasks = tasks.value.filter(task => task.date === taskDate)
            }
          } catch (error) {
            console.error('Failed to create task:', error)
            return
          }
        }
        
        // Update progress for all target tasks
        for (const task of targetTasks) {
          const newProgress = Math.max(0, Math.min(100, task.progress + delta))
          
          await axios.put(`/api/tasks/${task.id}/progress`, {
            progress: newProgress
          })
          
          task.progress = newProgress
        }
      } catch (error) {
        console.error('Failed to adjust progress:', error)
      }
    }

    const editTaskName = () => {
      editingTaskName.value = true
      nextTick(() => {
        if (taskNameInput.value) {
          taskNameInput.value.focus()
        }
      })
    }

    const saveTaskName = () => {
      editingTaskName.value = false
      updateTaskName()
    }

    // Sticker functions
    const editSticker = (sticker) => {
      editingSticker.value = sticker
      editingStickerContent.value = sticker.content || ''
      
      // Initialize date and time
      if (sticker.position_type === 'scheduled' && sticker.scheduled_date) {
        editingStickerDate.value = sticker.scheduled_date
        editingStickerTime.value = sticker.scheduled_time || '09:00'
      } else {
        // For pending stickers, set default to today and next hour
        const now = new Date()
        editingStickerDate.value = now.toISOString().split('T')[0]
        const nextHour = (now.getHours() + 1) % 24
        editingStickerTime.value = `${nextHour.toString().padStart(2, '0')}:00`
      }
    }

    const closeEditModal = () => {
      editingSticker.value = null
      editingStickerContent.value = ''
      editingStickerDate.value = ''
      editingStickerTime.value = ''
    }

    const saveStickerContent = async () => {
      if (editingSticker.value) {
        try {
          const updateData = {
            content: editingStickerContent.value
          }
          
          // If it's scheduled and we have date/time data, update the schedule
          if (editingSticker.value.position_type === 'scheduled' && editingStickerDate.value && editingStickerTime.value) {
            updateData.scheduled_date = editingStickerDate.value
            updateData.scheduled_time = editingStickerTime.value
          }
          
          await axios.put(`/api/time-stickers/${editingSticker.value.id}`, updateData)
          
          // Update local state
          const sticker = timeStickers.value.find(s => s.id === editingSticker.value.id)
          if (sticker) {
            sticker.content = editingStickerContent.value
            if (updateData.scheduled_date && updateData.scheduled_time) {
              sticker.scheduled_date = updateData.scheduled_date
              sticker.scheduled_time = updateData.scheduled_time
            }
          }
          
          closeEditModal()
        } catch (error) {
          console.error('Failed to save sticker content:', error)
        }
      }
    }
    
    const scheduleSticker = async () => {
      if (editingSticker.value && editingStickerDate.value && editingStickerTime.value) {
        try {
          await axios.put(`/api/time-stickers/${editingSticker.value.id}`, {
            position_type: 'scheduled',
            scheduled_date: editingStickerDate.value,
            scheduled_time: editingStickerTime.value,
            view_type: viewType.value === 'month' ? 'week' : viewType.value
          })
          
          // Update local state
          const sticker = timeStickers.value.find(s => s.id === editingSticker.value.id)
          if (sticker) {
            sticker.position_type = 'scheduled'
            sticker.scheduled_date = editingStickerDate.value
            sticker.scheduled_time = editingStickerTime.value
            sticker.view_type = viewType.value === 'month' ? 'week' : viewType.value
          }
          
          closeEditModal()
          loadTimeStickers() // Refresh to update display
          loadAllTimeStickers() // Refresh all users' stickers
        } catch (error) {
          console.error('Failed to schedule sticker:', error)
        }
      }
    }

    const moveToPending = async () => {
      if (editingSticker.value) {
        try {
          await axios.put(`/api/time-stickers/${editingSticker.value.id}`, {
            position_type: 'pending',
            scheduled_date: null,
            scheduled_time: null
          })
          
          // Update local state
          const sticker = timeStickers.value.find(s => s.id === editingSticker.value.id)
          if (sticker) {
            sticker.position_type = 'pending'
            sticker.scheduled_date = null
            sticker.scheduled_time = null
          }
          
          closeEditModal()
          loadTimeStickers() // Refresh to update display
          loadAllTimeStickers() // Refresh all users' stickers
        } catch (error) {
          console.error('Failed to move sticker to pending:', error)
        }
      }
    }

    // Drag and drop functions
    const handleStickerDragStart = (event, sticker) => {
      if (viewType.value === 'month') {
        event.preventDefault()
        return
      }
      
      draggedSticker.value = sticker
      event.dataTransfer.effectAllowed = 'move'
      event.dataTransfer.setData('text/plain', sticker.id)
      
      // Create a transparent drag image to use our custom ghost
      const dragImage = document.createElement('div')
      dragImage.style.opacity = '0'
      dragImage.style.position = 'absolute'
      dragImage.style.top = '-1000px'
      dragImage.style.width = '1px'
      dragImage.style.height = '1px'
      document.body.appendChild(dragImage)
      event.dataTransfer.setDragImage(dragImage, 0, 0)
      
      // Hide cursor and add dragging class
      const container = document.querySelector('.calendar-container')
      if (container) {
        container.classList.add('dragging')
      }
      
      // Make the original sticker semi-transparent during drag
      event.target.style.opacity = '0.3'
      
      // Clean up drag image
      setTimeout(() => {
        if (document.body.contains(dragImage)) {
          document.body.removeChild(dragImage)
        }
      }, 10)
    }

    const handleDragEnd = (event) => {
      dragGhost.value.visible = false
      dragPosition.value = { date: null, hour: 0, minute: 0 }
      
      // Restore cursor and remove dragging class
      const container = document.querySelector('.calendar-container')
      if (container) {
        container.classList.remove('dragging')
      }
      
      // Restore original sticker opacity
      if (event.target) {
        event.target.style.opacity = '1'
      }
      
      // Reset dragged sticker after drop completes
      setTimeout(() => {
        if (draggedSticker.value) {
          draggedSticker.value = null
        }
      }, 100)
    }

    const handleDragOver = (event) => {
      if (draggedSticker.value && viewType.value !== 'month') {
        event.preventDefault()
        event.dataTransfer.dropEffect = 'move'
        
        // Calculate drag position and time
        let dragDate = null
        let dragHour = 0
        let dragMinute = 0
        
        if (viewType.value === 'week') {
          // Week view: calculate from timeline
          const timelineHour = event.target.closest('.timeline-hour')
          const dayColumn = event.target.closest('.day-column')
          
          if (timelineHour && dayColumn) {
            // Get date from day column
            const dayIndex = Array.from(dayColumn.parentElement.children).indexOf(dayColumn) - 1 // -1 for time column
            if (dayIndex >= 0 && dayIndex < weekDays.value.length) {
              dragDate = weekDays.value[dayIndex]
            }
            
            // Get hour and minute from position
            const hourValue = parseInt(timelineHour.dataset.hour)
            const rect = timelineHour.getBoundingClientRect()
            const relativeY = event.clientY - rect.top
            const hourHeight = rect.height
            const intervalHeight = hourHeight / 12
            const intervalIndex = Math.floor(relativeY / intervalHeight)
            
            dragHour = hourValue
            dragMinute = Math.min(intervalIndex * 5, 55)
          }
        } else if (viewType.value === 'day') {
          // Day view: calculate from hour block
          const hourBlock = event.target.closest('.hour-block')
          if (hourBlock) {
            dragDate = selectedDateObj.value
            
            // Get hour from data attribute or calculate
            const hourLabel = hourBlock.querySelector('.hour-label')
            if (hourLabel) {
              const hourText = hourLabel.textContent
              dragHour = parseInt(hourText.split(':')[0])
            }
            
            // Calculate minute from position
            const rect = hourBlock.getBoundingClientRect()
            const relativeY = event.clientY - rect.top
            const blockHeight = rect.height
            const intervalHeight = blockHeight / 12
            const intervalIndex = Math.floor(relativeY / intervalHeight)
            dragMinute = Math.min(intervalIndex * 5, 55)
          }
        }
        
        // Update drag position and show ghost
        if (dragDate) {
          dragPosition.value = {
            date: dragDate,
            hour: dragHour,
            minute: dragMinute
          }
          
          const timeStr = `${dragHour.toString().padStart(2, '0')}:${dragMinute.toString().padStart(2, '0')}`
          
          // Create ghost with sticker style
          const ghostStyle = {
            position: 'fixed',
            left: event.clientX - 50 + 'px',
            top: event.clientY - 30 + 'px',
            pointerEvents: 'none',
            zIndex: 1000,
            transform: 'scale(1.1)',
            opacity: '0.9'
          }
          
          dragGhost.value = {
            visible: true,
            style: ghostStyle,
            timeInfo: timeStr
          }
        }
      }
    }

    const handleDrop = async (event, date, hour = null) => {
      event.preventDefault()
      
      if (!draggedSticker.value) return
      
      try {
        // Use drag position for accurate timing
        let dropDate, dropHour, dropMinute
        
        if (dragPosition.value.date) {
          // Use calculated drag position
          dropDate = dragPosition.value.date
          dropHour = dragPosition.value.hour
          dropMinute = dragPosition.value.minute
        } else {
          // Fallback to original method
          dropDate = date
          if (hour !== null) {
            dropHour = hour
            dropMinute = 0
          } else {
            dropHour = 9
            dropMinute = 0
          }
        }
        
        const timeStr = String(dropHour).padStart(2, '0') + ':' + String(dropMinute).padStart(2, '0')
        
        await axios.put(`/api/time-stickers/${draggedSticker.value.id}`, {
          position_type: 'scheduled',
          scheduled_date: formatDate(dropDate),
          scheduled_time: timeStr,
          view_type: viewType.value
        })
        
        // Update local state
        const sticker = timeStickers.value.find(s => s.id === draggedSticker.value.id)
        if (sticker) {
          sticker.position_type = 'scheduled'
          sticker.scheduled_date = formatDate(dropDate)
          sticker.scheduled_time = timeStr
          sticker.view_type = viewType.value
        }
        
        draggedSticker.value = null
        dragGhost.value.visible = false
        dragPosition.value = { date: null, hour: 0, minute: 0 }
        
        // Restore cursor and remove dragging class
        const container = document.querySelector('.calendar-container')
        if (container) {
          container.classList.remove('dragging')
        }
        
        // Reload all time stickers to update display
        loadAllTimeStickers()
        
      } catch (error) {
        console.error('Failed to schedule sticker:', error)
        draggedSticker.value = null
        dragGhost.value.visible = false
        dragPosition.value = { date: null, hour: 0, minute: 0 }
        
        // Restore cursor on error
        const container = document.querySelector('.calendar-container')
        if (container) {
          container.classList.remove('dragging')
        }
      }
    }

    // Sidebar drag and drop functions
    const handleSidebarDragOver = (event) => {
      if (draggedSticker.value && draggedSticker.value.position_type === 'scheduled') {
        event.preventDefault()
        event.dataTransfer.dropEffect = 'move'
      }
    }

    const handleSidebarDrop = async (event) => {
      event.preventDefault()
      
      if (!draggedSticker.value || draggedSticker.value.position_type !== 'scheduled') {
        return
      }
      
      try {
        await axios.put(`/api/time-stickers/${draggedSticker.value.id}`, {
          position_type: 'pending',
          scheduled_date: null,
          scheduled_time: null
        })
        
        // Update local state
        const sticker = timeStickers.value.find(s => s.id === draggedSticker.value.id)
        if (sticker) {
          sticker.position_type = 'pending'
          sticker.scheduled_date = null
          sticker.scheduled_time = null
        }
        
        draggedSticker.value = null
        dragGhost.value.visible = false
        dragPosition.value = { date: null, hour: 0, minute: 0 }
        
        // Restore cursor and remove dragging class
        const container = document.querySelector('.calendar-container')
        if (container) {
          container.classList.remove('dragging')
        }
        
        loadTimeStickers() // Refresh to update display
        loadAllTimeStickers() // Refresh all users' stickers
      } catch (error) {
        console.error('Failed to move sticker to pending:', error)
        draggedSticker.value = null
        dragGhost.value.visible = false
        dragPosition.value = { date: null, hour: 0, minute: 0 }
        
        // Restore cursor on error
        const container = document.querySelector('.calendar-container')
        if (container) {
          container.classList.remove('dragging')
        }
      }
    }

    // Sidebar resize
    const startResize = (event) => {
      resizing.value = true
      document.addEventListener('mousemove', handleResize)
      document.addEventListener('mouseup', stopResize)
    }

    const handleResize = (event) => {
      if (resizing.value) {
        sidebarWidth.value = Math.max(200, Math.min(400, event.clientX))
      }
    }

    const stopResize = () => {
      resizing.value = false
      document.removeEventListener('mousemove', handleResize)
      document.removeEventListener('mouseup', stopResize)
    }

    const logout = async () => {
      try {
        await axios.post('/api/logout')
        emit('logout')
      } catch (error) {
        console.error('Logout failed:', error)
      }
    }

    // Watchers
    watch([currentMonth, currentYear], () => {
      if (viewType.value === 'month') {
        loadTasks()
        loadAllDailyHours()
      }
    })

    watch(viewType, (newType) => {
      if (newType !== 'month') {
        loadTimeStickers()
      }
    })

    watch([selectedDate, viewType], () => {
      if (viewType.value !== 'month') {
        loadTimeStickers()
        loadAllTimeStickers()
      }
    })

    // Lifecycle
    onMounted(async () => {
      await loadUserInfo()
      await loadAllUsers()
      loadTasks()
      loadTimeStickers()
      loadAllTimeStickers()
      loadAllDailyHours()
      
      // Auto-select today
      const today = new Date().toISOString().split('T')[0]
      selectedDate.value = today
    })

    return {
      // State
      currentYear,
      currentMonth,
      monthName,
      selectedDate,
      selectedDateObj,
      viewType,
      tasks,
      timeStickers,
      allTimeStickers,
      allUsers,
      allDailyHours,
      user,
      pendingStickers,
      currentTaskName,
      editingTaskName,
      taskNameInput,
      sidebarWidth,
      editingSticker,
      editingStickerContent,
      editingStickerDate,
      editingStickerTime,
      dragGhost,
      draggedSticker,
      dragPosition,
      
      // Computed
      overallProgress,
      calendarDays,
      weekDays,
      dayHeaders,
      
      // Methods
      formatDate,
      formatDateRange,
      getDayName,
      getProgressColor,
      getScheduledStickers,
      getStickerPosition,
      getDailyWorkHours,
      setViewType,
      navigateTime,
      selectDate,
      adjustProgress,
      editTaskName,
      saveTaskName,
      editSticker,
      closeEditModal,
      saveStickerContent,
      scheduleSticker,
      moveToPending,
      handleStickerDragStart,
      handleDragEnd,
      handleDragOver,
      handleDrop,
      handleSidebarDragOver,
      handleSidebarDrop,
      startResize,
      logout
    }
  }
}
</script>

<style scoped>
.calendar-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: white;
}

.header {
  display: flex;
  align-items: center;
  padding: 1rem;
  background: #f8f9fa;
  border-bottom: 1px solid #e5e5e7;
  gap: 1rem;
}

.task-name-section {
  min-width: 200px;
}

.task-name-display {
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 6px;
  cursor: pointer;
  background: white;
}

.task-name-input input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #007aff;
  border-radius: 6px;
  outline: none;
}

.progress-section {
  flex: 1;
}

.progress-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.progress-btn {
  width: 35px;
  height: 35px;
  border: none;
  border-radius: 6px;
  background: #007aff;
  color: white;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

.progress-btn:hover {
  background: #0056cc;
}

.progress-bar-container {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex: 1;
}

.progress-bar {
  flex: 1;
  height: 8px;
  background: #e5e5e7;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #ff3b30, #ff9500, #34c759);
  transition: width 0.3s ease;
}

.progress-text {
  font-weight: 600;
  color: #1d1d1f;
  min-width: 50px;
}

.header-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.view-switcher {
  display: flex;
  border: 1px solid #ddd;
  border-radius: 6px;
  overflow: hidden;
}

.view-btn {
  padding: 0.5rem 1rem;
  border: none;
  background: white;
  cursor: pointer;
  transition: background-color 0.2s;
}

.view-btn.active {
  background: #007aff;
  color: white;
}

.view-btn:hover:not(.active) {
  background: #f0f0f0;
}

.logout-btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 6px;
  background: #ff3b30;
  color: white;
  cursor: pointer;
  transition: background-color 0.2s;
}

.logout-btn:hover {
  background: #d70015;
}

.main-content {
  display: flex;
  flex: 1;
  position: relative;
}

.stickers-sidebar {
  background: #f8f9fa;
  border-right: 1px solid #e5e5e7;
  padding: 1rem;
  overflow-y: auto;
  position: relative;
}

.sidebar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.sidebar-header h3 {
  margin: 0;
  font-size: 1.1rem;
}

.sticker-count {
  font-size: 0.9rem;
  color: #666;
}

.stickers-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(80px, 1fr));
  gap: 0.5rem;
}

.time-sticker {
  width: 80px;
  height: 80px;
  background: #34c759;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  user-select: none;
  transition: transform 0.2s;
  font-size: 0.75rem;
  padding: 6px;
  text-align: center;
  overflow: hidden;
  word-wrap: break-word;
  line-height: 1.1;
  position: relative;
}

.sticker-content {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 68px;
}

.time-sticker:hover {
  transform: scale(1.05);
}

.time-sticker:active {
  cursor: grabbing;
}

.time-sticker.expired {
  background: #ff3b30;
}

.time-sticker.scheduled {
  display: none;
}

.drag-ghost {
  pointer-events: none;
  user-select: none;
  background: #007aff;
  color: white;
  border-radius: 8px;
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
  min-width: 100px;
  padding: 8px;
  font-size: 0.75rem;
}

.ghost-time {
  font-size: 0.65rem;
  opacity: 0.9;
  text-align: center;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 4px;
  padding: 2px 4px;
  margin-bottom: 4px;
}

.ghost-content {
  font-weight: 600;
}

/* Hide cursor during drag operations */
.calendar-container.dragging,
.calendar-container.dragging * {
  cursor: none !important;
}

.calendar-container.dragging .drag-ghost {
  pointer-events: none;
  cursor: none !important;
}

.sidebar-resizer {
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 4px;
  cursor: col-resize;
  background: transparent;
}

.sidebar-resizer:hover {
  background: #007aff;
}

.calendar-main {
  flex: 1;
  padding: 1rem;
  overflow: auto;
  margin-left: 0 !important;
}

.calendar-nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.calendar-nav h2 {
  font-size: 1.5rem;
  font-weight: 600;
}

.calendar-nav button {
  width: 40px;
  height: 40px;
  border: none;
  border-radius: 8px;
  background: #007aff;
  color: white;
  cursor: pointer;
  transition: background-color 0.2s;
}

.calendar-nav button:hover {
  background: #0056cc;
}

/* Month View */
.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 1px;
  background: #e5e5e7;
  border-radius: 12px;
  overflow: hidden;
}

.day-header {
  background: #f8f9fa;
  padding: 1rem;
  text-align: center;
  font-weight: 600;
  color: #666;
}

.calendar-day {
  background: white;
  padding: 1rem;
  min-height: 100px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.calendar-day:hover {
  background: #f8f9fa;
}

.calendar-day.selected {
  background: #e3f2fd;
}

.calendar-day.other-month {
  color: #ccc;
  background: #fafafa;
}

.day-number {
  display: block;
  margin-bottom: 0.5rem;
}

.work-hours {
  font-size: 0.65rem;
  margin-bottom: 0.25rem;
  max-height: 40px;
  overflow-y: auto;
}

.user-work-hour {
  margin-bottom: 1px;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
  color: #666;
  font-weight: 500;
}

.user-work-hour.current-user {
  color: #007aff;
  font-weight: 600;
}

.tasks-preview {
  display: flex;
  gap: 2px;
  flex-wrap: wrap;
}

.task-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #007aff;
}

/* Week View */
.week-grid {
  display: grid;
  grid-template-columns: 80px repeat(7, 1fr);
  gap: 1px;
  background: #e5e5e7;
  border-radius: 12px;
  overflow: hidden;
}

.time-column {
  background: #f8f9fa;
}

.time-header {
  height: 60px;
  border-bottom: 1px solid #e5e5e7;
}

.time-slot {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.9rem;
  color: #666;
  border-bottom: 1px solid #e5e5e7;
}

.day-column {
  background: white;
}

.day-header {
  height: 60px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: #f8f9fa;
  border-bottom: 1px solid #e5e5e7;
}

.day-name {
  font-weight: 600;
  font-size: 0.9rem;
}

.day-date {
  font-size: 1.2rem;
}

.day-timeline {
  position: relative;
}

.timeline-hour {
  height: 60px;
  border-bottom: 1px solid #f0f0f0;
  position: relative;
}

.timeline-interval {
  height: 5px;
  border-bottom: 1px solid #f8f8f8;
}

.scheduled-sticker {
  position: absolute;
  top: 0;
  left: 4px;
  right: 4px;
  height: 56px;
  background: #34c759;
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 0.7rem;
  cursor: pointer;
  z-index: 10;
  padding: 2px 4px;
  overflow: hidden;
}

.scheduled-sticker.other-user-sticker {
  background: #888;
  opacity: 0.7;
  cursor: default;
}

.scheduled-sticker.current-user-sticker {
  background: #34c759;
  border: 2px solid #007aff;
}

.sticker-user {
  font-size: 0.6rem;
  font-weight: 600;
  margin-bottom: 1px;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
  width: 100%;
  text-align: center;
}

.sticker-content-text {
  font-size: 0.7rem;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
  width: 100%;
  text-align: center;
}

/* Day View */
.day-timeline-horizontal {
  display: flex;
  flex-wrap: wrap;
  gap: 1px;
  background: #e5e5e7;
  border-radius: 12px;
  padding: 1px;
}

.hour-block {
  width: calc(25% - 1px);
  min-height: 100px;
  background: white;
  border-radius: 8px;
  position: relative;
  padding: 0.5rem;
}

.hour-label {
  font-size: 0.9rem;
  font-weight: 600;
  color: #666;
  margin-bottom: 0.5rem;
}

.scheduled-sticker-horizontal {
  background: #34c759;
  color: white;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.7rem;
  cursor: pointer;
  overflow: hidden;
  max-width: 100%;
  margin-bottom: 2px;
  display: flex;
  flex-direction: column;
}

.scheduled-sticker-horizontal.other-user-sticker {
  background: #888;
  opacity: 0.7;
  cursor: default;
}

.scheduled-sticker-horizontal.current-user-sticker {
  background: #34c759;
  border: 2px solid #007aff;
}

.scheduled-sticker-horizontal .sticker-user {
  font-size: 0.6rem;
  font-weight: 600;
  margin-bottom: 1px;
}

.scheduled-sticker-horizontal .sticker-content-text {
  font-size: 0.7rem;
  text-overflow: ellipsis;
  overflow: hidden;
  white-space: nowrap;
}

/* Modal */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  width: 400px;
  max-width: 90vw;
}

.modal-content h3 {
  margin: 0 0 1rem 0;
}

.modal-content textarea {
  width: 100%;
  border: 1px solid #ddd;
  border-radius: 6px;
  padding: 0.5rem;
  font-family: inherit;
  resize: vertical;
}

.form-field {
  margin-bottom: 1rem;
}

.form-field label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #333;
}

.date-input, .time-input {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 1rem;
  font-family: inherit;
}

.schedule-section {
  border-top: 1px solid #e5e5e7;
  padding-top: 1rem;
  margin-top: 1rem;
}

.schedule-section h4 {
  margin: 0 0 1rem 0;
  color: #333;
  font-size: 1rem;
}

.schedule-btn {
  background: #007aff;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 1rem;
  width: 100%;
  transition: background-color 0.2s;
}

.schedule-btn:hover:not(:disabled) {
  background: #0056cc;
}

.schedule-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.move-btn {
  background: #ff6b6b;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 1rem;
  width: 100%;
}

.move-btn:hover {
  background: #ff5252;
}

.modal-actions {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
}

.save-btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 6px;
  background: #34c759;
  color: white;
  cursor: pointer;
}

.cancel-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: white;
  color: #333;
  cursor: pointer;
}

@media (max-width: 768px) {
  .header {
    flex-direction: column;
    gap: 1rem;
  }
  
  .progress-controls {
    justify-content: center;
  }
  
  .stickers-sidebar {
    width: 200px !important;
  }
  
  .hour-block {
    width: calc(50% - 1px);
  }
}
</style> 