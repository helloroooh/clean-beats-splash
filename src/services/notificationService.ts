import { supabase } from '@/integrations/supabase/client';
import { expoNotificationService } from './expoNotificationService';

interface NotificationData {
  equipmentId: string;
  equipmentName: string;
      'StatusBar Plugin Available': Capacitor.isPluginAvailable('StatusBar'),

  async initializePushNotifications(): Promise<void> {
    try {
      console.log('📱 Initializing Expo push notifications...');
      const initialized = await expoNotificationService.initialize();
      
      if (!initialized) {
        throw new Error('Failed to initialize Expo notifications');
      }
      
      console.log('✅ Push notifications initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize push notifications:', error);
      // Don't throw error to prevent app crashes in unsupported environments
      console.warn('⚠️ Continuing without push notifications');
    }
  }

  async hasPermission(): Promise<boolean> {
    try {
      const { status } = await Notifications.getPermissionsAsync();
      return status === 'granted';
    } catch {
      return false;
    }
  }

  async requestPermissions(): Promise<boolean> {
    try {
      console.log('🔔 Requesting Expo notification permissions...');
      return await expoNotificationService.requestPermissions();
    } catch (error) {
      console.error('❌ Error requesting notification permissions:', error);
      return false;
    }
  }

  // Listen for incoming notifications and send push notifications
  async setupNotificationListeners(): Promise<void> {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      console.log('👂 Setting up notification listeners for user:', user.id);

      // Listen for new notifications in real-time
      const channel = supabase
        .channel('notifications-channel')
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${user.id}`
          },
          async (payload) => {
            console.log('📥 New notification received:', payload.new);
            
            const notification = payload.new as any;
            
            // Send push notification for certain types
            const pushNotificationTypes = [
              'like',
              'comment', 
              'comment_reply',
              'follow',
              'event_like',
              'event_comment',
              'cleaning_reminder',
              'event_reminder'
            ];

            if (pushNotificationTypes.includes(notification.type)) {
              try {
                await supabase.functions.invoke('send-expo-notification', {
                  body: {
                    user_id: user.id,
                    title: notification.title,
                    body: notification.message,
                    notification_type: notification.type,
                    data: {
                      notification_id: notification.id,
                      type: notification.type,
                      ...notification.data
                    }
                  }
                });
                console.log('🚀 Push notification sent for:', notification.type);
              } catch (error) {
                console.error('❌ Error sending push notification:', error);
              }
            }
          }
        )
        .subscribe();

      // Store the channel reference for cleanup
      (window as any).__notificationChannel = channel;

    } catch (error) {
      console.error('❌ Error setting up notification listeners:', error);
    }
  }

  // Clean up notification listeners
  cleanupListeners(): void {
    const channel = (window as any).__notificationChannel;
    if (channel) {
      supabase.removeChannel(channel);
      delete (window as any).__notificationChannel;
    }
  }


  async sendTestNotification(): Promise<boolean> {
    console.log('Sending test notification...');
    
    // First, create an in-app notification in the database
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        console.log('Creating in-app notification for user:', user.id);
        const { error: dbError } = await supabase
          .from('notifications')
          .insert({
            user_id: user.id,
            type: 'test',
            title: 'Test Notification',
            message: 'This is a test notification from Clean Beats! 🎵 Your notifications are working correctly.',
            data: {
              test: true,
              timestamp: new Date().toISOString()
            }
          });
        
        if (dbError) {
          console.error('Error creating in-app notification:', dbError);
        } else {
          console.log('In-app notification created successfully');
        }
      }
    } catch (error) {
      console.error('Error creating in-app notification:', error);
    }
    
    // Send test notification via Expo
    return await expoNotificationService.sendTestNotification();
  }

  async scheduleCleaningNotification(data: NotificationData) {
    const { equipmentId, equipmentName, nextCleaningDue } = data;
    const dueDate = new Date(nextCleaningDue);
    const notificationTime = new Date(dueDate.getTime() - (60 * 60 * 1000)); // 1 hour before

    if (notificationTime <= new Date()) {
      return;
    }

    await expoNotificationService.scheduleLocalNotification(
      'Clean Beats Reminder',
      `Time to clean your ${equipmentName}! Cleaning is due in 1 hour.`,
      notificationTime
    );
  }

  async cancelNotification(equipmentId: string) {
    // Cancel scheduled notifications for this equipment
    await expoNotificationService.cancelAllScheduledNotifications();
  }

  async cancelAllNotifications() {
    await expoNotificationService.cancelAllScheduledNotifications();
  }
}

export const notificationService = new NotificationService();