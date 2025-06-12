<template>
  <div class="login-container">
    <div class="login-form">
      <h1>Schedule App</h1>
      <div class="form-group">
        <input 
          v-model="username" 
          type="text" 
          placeholder="Username" 
          @keyup.enter="handleSubmit"
        />
      </div>
      <div class="form-group">
        <input 
          v-model="password" 
          type="password" 
          placeholder="Password" 
          @keyup.enter="handleSubmit"
        />
      </div>
      <div class="form-actions">
        <button @click="handleSubmit" :disabled="loading">
          {{ isRegister ? 'Register' : 'Login' }}
        </button>
        <button @click="toggleMode" class="link-button">
          {{ isRegister ? 'Already have an account? Login' : 'Need an account? Register' }}
        </button>
      </div>
      <div v-if="error" class="error">{{ error }}</div>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import axios from 'axios'

export default {
  name: 'LoginForm',
  emits: ['login'],
  setup(props, { emit }) {
    const username = ref('')
    const password = ref('')
    const isRegister = ref(false)
    const loading = ref(false)
    const error = ref('')

    const toggleMode = () => {
      isRegister.value = !isRegister.value
      error.value = ''
    }

    const handleSubmit = async () => {
      if (!username.value || !password.value) {
        error.value = 'Please fill in all fields'
        return
      }

      loading.value = true
      error.value = ''

      try {
        const endpoint = isRegister.value ? '/api/register' : '/api/login'
        const response = await axios.post(endpoint, {
          username: username.value,
          password: password.value
        })

        if (response.data.user_id) {
          emit('login')
        }
      } catch (err) {
        error.value = err.response?.data?.error || 'An error occurred'
      } finally {
        loading.value = false
      }
    }

    return {
      username,
      password,
      isRegister,
      loading,
      error,
      toggleMode,
      handleSubmit
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-form {
  background: white;
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
  width: 100%;
  max-width: 400px;
}

h1 {
  text-align: center;
  margin-bottom: 2rem;
  color: #1d1d1f;
  font-weight: 600;
}

.form-group {
  margin-bottom: 1rem;
}

input {
  width: 100%;
  padding: 0.75rem;
  border: 2px solid #e5e5e7;
  border-radius: 8px;
  font-size: 1rem;
  transition: border-color 0.2s;
}

input:focus {
  outline: none;
  border-color: #007aff;
}

.form-actions {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

button {
  padding: 0.75rem;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

button:first-child {
  background: #007aff;
  color: white;
}

button:first-child:hover {
  background: #0056cc;
}

button:first-child:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.link-button {
  background: none;
  color: #007aff;
  text-decoration: underline;
  font-size: 0.9rem;
}

.link-button:hover {
  color: #0056cc;
}

.error {
  color: #ff3b30;
  text-align: center;
  margin-top: 1rem;
  font-size: 0.9rem;
}
</style> 