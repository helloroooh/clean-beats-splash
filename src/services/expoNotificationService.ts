import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { Platform } from 'react-native';
import { supabase } from '@/integrations/supabase/client';

// Configure notification behavior
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

interface NotificationData {
  equipmentId?: string;
  equipmentName?: string;
  nextCleaningDue?: string;
  postId?: string;
  eventId?: string;
  userId?: string;
  type?: string;
}

class ExpoNotificationService {
  private isInitialized = false;
  private expoPushToken: string | null = null;

  async initialize(): Promise<boolean> {
    if (this.isInitialized) return true;

    try {
      console.log('🔔 Initializing Expo Notifications...');
      
      // Check if running on a physical device
      if (!Device.isDevice) {
        console.warn('⚠️ Push notifications only work on physical devices');
        return false;
      }

      // Request permissions
      const hasPermission = await this.requestPermissions();
      if (!hasPermission) {
        console.warn('⚠️ Notification permissions not granted');
        return false;
      }

      // Get Expo push token
      const token = await this.getExpoPushToken();
      if (!token) {
        console.error('❌ Failed to get Expo push token');
        return false;
      }

      this.expoPushToken = token;
      this.isInitialized = true;

      // Save token to database
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        await this.saveTokenToDatabase(token, user.id);
      }

      // Set up notification listeners
      this.setupNotificationListeners();

      console.log('✅ Expo Notifications initialized successfully');
      return true;
    } catch (error) {
      console.error('❌ Failed to initialize Expo Notifications:', error);
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }

      if (finalStatus !== 'granted') {
        console.warn('⚠️ Notification permissions denied');
        return false;
      }

      console.log('✅ Notification permissions granted');
      return true;
    } catch (error) {
      console.error('❌ Error requesting permissions:', error);
      return false;
    }
  }

  async getExpoPushToken(): Promise<string | null> {
    try {
      const projectId = Constants.expoConfig?.extra?.eas?.projectId;
      
      if (!projectId) {
        console.error('❌ No Expo project ID found');
        return null;
      }

      const token = await Notifications.getExpoPushTokenAsync({
        projectId,
      });

      console.log('✅ Expo push token obtained:', token.data.substring(0, 20) + '...');
      return token.data;
    } catch (error) {
      console.error('❌ Error getting Expo push token:', error);
      return null;
    }
  }

  async saveTokenToDatabase(token: string, userId: string): Promise<boolean> {
    try {
      const deviceInfo = {
        platform: Platform.OS,
        deviceName: Device.deviceName,
        osVersion: Device.osVersion,
        modelName: Device.modelName,
        timestamp: new Date().toISOString()
      };

      const { error } = await supabase
        .from('fcm_tokens')
        .upsert({
          user_id: userId,
          token,
          platform: `expo-${Platform.OS}`,
          device_info: deviceInfo,
          is_active: true,
          last_used_at: new Date().toISOString()
        }, {
          onConflict: 'user_id,platform,token'
        });

      if (error) {
        console.error('❌ Error saving Expo token:', error);
        return false;
      }

      console.log('✅ Expo token saved successfully');
      return true;
    } catch (error) {
      console.error('❌ Error saving token to database:', error);
      return false;
    }
  }

  private setupNotificationListeners(): void {
    // Listen for notifications received while app is foregrounded
    Notifications.addNotificationReceivedListener(notification => {
      console.log('📱 Notification received in foreground:', notification);
      // Handle foreground notification display
    });

    // Listen for notification interactions (taps)
    Notifications.addNotificationResponseReceivedListener(response => {
      console.log('📱 Notification tapped:', response);
      this.handleNotificationResponse(response);
    });
  }

  private handleNotificationResponse(response: Notifications.NotificationResponse): void {
    const data = response.notification.request.content.data as NotificationData;
    
    // Handle navigation based on notification type
    if (data.type === 'cleaning_reminder' && data.equipmentId) {
      // Navigate to equipment page
      // This would need to be handled by the app's navigation system
    } else if (data.type === 'comment' && data.postId) {
      // Navigate to community page
    } else if (data.type === 'event_reminder' && data.eventId) {
      // Navigate to calendar page
    }
  }

  async sendTestNotification(): Promise<boolean> {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.error('❌ User not authenticated');
        return false;
      }

      // Send test notification via Supabase edge function
      const { error } = await supabase.functions.invoke('send-expo-notification', {
        body: {
          userId: user.id,
          title: 'Clean Beats Test 🎵',
          body: 'This is a test notification from Clean Beats!',
          data: {
            type: 'test',
            timestamp: new Date().toISOString()
          }
        }
      });

      if (error) {
        console.error('❌ Error sending test notification:', error);
        return false;
      }

      console.log('✅ Test notification sent successfully');
      return true;
    } catch (error) {
      console.error('❌ Error sending test notification:', error);
      return false;
    }
  }

  async scheduleLocalNotification(title: string, body: string, trigger: Date): Promise<void> {
    try {
      await Notifications.scheduleNotificationAsync({
        content: {
          title,
          body,
          sound: 'default',
        },
        trigger: {
          date: trigger,
        },
      });
      console.log('✅ Local notification scheduled');
    } catch (error) {
      console.error('❌ Error scheduling local notification:', error);
    }
  }

  async cancelAllScheduledNotifications(): Promise<void> {
    try {
      await Notifications.cancelAllScheduledNotificationsAsync();
      console.log('✅ All scheduled notifications cancelled');
    } catch (error) {
      console.error('❌ Error cancelling notifications:', error);
    }
  }

  getToken(): string | null {
    return this.expoPushToken;
  }

  isServiceInitialized(): boolean {
    return this.isInitialized;
  }
}

export const expoNotificationService = new ExpoNotificationService();