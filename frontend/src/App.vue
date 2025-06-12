<template>
  <div id="app">
    <LoginForm v-if="!isAuthenticated" @login="handleLogin" />
    <Calendar v-else @logout="handleLogout" />
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import axios from 'axios'
import LoginForm from './components/LoginForm.vue'
import Calendar from './components/Calendar.vue'

// Configure axios defaults
axios.defaults.withCredentials = true

export default {
  name: 'App',
  components: {
    LoginForm,
    Calendar
  },
  setup() {
    const isAuthenticated = ref(false)

    const checkAuth = async () => {
      try {
        const response = await axios.get('/api/user')
        if (response.data.authenticated) {
          isAuthenticated.value = true
        }
      } catch (error) {
        console.log('Not authenticated')
      }
    }

    const handleLogin = () => {
      isAuthenticated.value = true
    }

    const handleLogout = () => {
      isAuthenticated.value = false
    }

    onMounted(() => {
      checkAuth()
    })

    return {
      isAuthenticated,
      handleLogin,
      handleLogout
    }
  }
}
</script>

<style>
#app {
  min-height: 100vh;
  width: 100%;
}
</style> 