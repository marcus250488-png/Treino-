package com.marcus.treino_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

class SonoSensorService : Service(), SensorEventListener {
    private lateinit var manager: SensorManager
    private var accel: Sensor? = null
    private var light: Sensor? = null
    private var proximity: Sensor? = null
    private var samples = 0
    private var movements = 0
    private var lastMotion = 0L
    private var lightSamples = 0
    private var proximitySamples = 0
    private var lastPersist = 0L
    private val prefs by lazy { getSharedPreferences("meutreino_sono_sensor", Context.MODE_PRIVATE) }

    override fun onCreate() {
        super.onCreate()
        manager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accel = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        light = manager.getDefaultSensor(Sensor.TYPE_LIGHT)
        proximity = manager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        createChannel()
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopTracking(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return START_NOT_STICKY }
            ACTION_START -> startTracking()
        }
        return START_STICKY
    }
    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Monitoramento do sono", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
    private fun startTracking() {
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Meu Treino • monitoramento do sono")
            .setContentText("Sensores ativos. Toque para voltar ao aplicativo.")
            .setOngoing(true).setCategory(NotificationCompat.CATEGORY_SERVICE).build()
        startForeground(NOTIFICATION_ID, notification)
        if (!prefs.getBoolean("ativo", false)) {
            samples = 0; movements = 0; lightSamples = 0; proximitySamples = 0
            prefs.edit().putLong("inicio", System.currentTimeMillis()).apply()
        } else {
            samples = prefs.getInt("amostras", 0); movements = prefs.getInt("movimentos", 0)
        }
        prefs.edit().putBoolean("ativo", true).apply()
        accel?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        light?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        proximity?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        persist()
    }
    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                samples++
                val magnitude = sqrt(event.values[0]*event.values[0] + event.values[1]*event.values[1] + event.values[2]*event.values[2])
                if (kotlin.math.abs(magnitude - SensorManager.GRAVITY_EARTH) > 1.15f) {
                    if (System.currentTimeMillis() - lastMotion > 5000) movements++
                    lastMotion = System.currentTimeMillis()
                }
            }
            Sensor.TYPE_LIGHT -> lightSamples++
            Sensor.TYPE_PROXIMITY -> proximitySamples++
        }
        if (System.currentTimeMillis() - lastPersist > 60000) persist()
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    private fun persist() {
        lastPersist = System.currentTimeMillis()
        prefs.edit().putBoolean("ativo", true).putInt("amostras", samples)
            .putInt("movimentos", movements).putInt("amostrasLuz", lightSamples)
            .putInt("amostrasProximidade", proximitySamples).apply()
    }
    private fun stopTracking() {
        manager.unregisterListener(this)
        persist()
        prefs.edit().putBoolean("ativo", false).putLong("fim", System.currentTimeMillis()).apply()
    }
    override fun onDestroy() {
        if (prefs.getBoolean("ativo", false)) manager.unregisterListener(this)
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "com.marcus.treino_app.SONO_START"
        const val ACTION_STOP = "com.marcus.treino_app.SONO_STOP"
        private const val CHANNEL = "meutreino_sono"
        private const val NOTIFICATION_ID = 8301
        fun status(context: Context): Map<String, Any> {
            val p = context.getSharedPreferences("meutreino_sono_sensor", Context.MODE_PRIVATE)
            val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            return mapOf("ativo" to p.getBoolean("ativo", false),
                "amostras" to p.getInt("amostras", 0), "movimentos" to p.getInt("movimentos", 0),
                "inicio" to p.getLong("inicio", 0L), "fim" to p.getLong("fim", 0L),
                "acelerometro" to (sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                "luz" to (sm.getDefaultSensor(Sensor.TYPE_LIGHT) != null),
                "proximidade" to (sm.getDefaultSensor(Sensor.TYPE_PROXIMITY) != null))
        }
    }
}
