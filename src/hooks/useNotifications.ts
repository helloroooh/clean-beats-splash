import { useState, useEffect } from 'react';
import { useToast } from '@/hooks/use-toast';
import { supabase } from '@/integrations/supabase/client';
import { expoNotificationService } from '@/services/expoNotificationService';

export const useNotifications = () => {
  const [hasPermission, setHasPermission] = useState(false);
  const [userTimezone, setUserTimezone] = useState<string>('UTC');
  const { toast } = useToast();

  useEffect(() => {
    initializeNotifications();
    detectTimezone();
  }, []);

  const initializeNotifications = async () => {
    try {
      // Initialize Expo notification service
      const initialized = await expoNotificationService.initialize();
      if (initialized) {
        // Check existing permissions
        const hasPerms = await checkPermissions();
        setHasPermission(hasPerms);

        // Register token if user is logged in and has permissions
        if (hasPerms) {
          const { data: { user } } = await supabase.auth.getUser();
          if (user) {
            const token = expoNotificationService.getToken();
            if (token) {
              await expoNotificationService.saveTokenToDatabase(token, user.id);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error initializing notifications:', error);
    }
  };

  const detectTimezone = () => {
    try {
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      setUserTimezone(timezone);
      saveUserTimezone(timezone);
    } catch (error) {
      console.error('Error detecting timezone:', error);
      setUserTimezone('UTC');
    }
  };

  const saveUserTimezone = async (timezone: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { error } = await supabase
        .from('user_timezones')
        .upsert({
          user_id: user.id,
          timezone,
          updated_at: new Date().toISOString()
        });

      if (error) {
        console.error('Error saving timezone:', error);
      }
    } catch (error) {
      console.error('Error saving user timezone:', error);
    }
  };

  const checkPermissions = async () => {
    try {
      // Initialize Expo service if not already done
      const initialized = await expoNotificationService.initialize();
      if (!initialized) {
        setHasPermission(false);
        return false;
      }

      // Check if we have a token (indicates permissions are granted)
      const token = expoNotificationService.getToken();
      const hasPerms = !!token;
      setHasPermission(hasPerms);
      return hasPerms;
    } catch (error) {
      console.error('Error checking Expo permissions:', error);
      setHasPermission(false);
      return false;
    }
  };

  const requestPermissions = async () => {
    try {
      // Initialize Expo service first
      const initialized = await expoNotificationService.initialize();
      if (!initialized) {
        toast({
          title: "Error",
          description: "Failed to initialize notification service",
          variant: "destructive",
        });
        return false;
      }

      // Request permissions
      const permissionGranted = await expoNotificationService.requestPermissions();
      if (!permissionGranted) {
        toast({
          title: "Notifications Disabled",
          description: "Enable notifications in settings to receive cleaning reminders",
          variant: "destructive",
        });
        setHasPermission(false);
        return false;
      }

      // Get Expo push token
      const token = expoNotificationService.getToken();
      if (!token) {
        toast({
          title: "Error",
          description: "Failed to get notification token",
          variant: "destructive",
        });
        setHasPermission(false);
        return false;
      }

      // Save token to database
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const tokenSaved = await expoNotificationService.saveTokenToDatabase(token, user.id);
        if (!tokenSaved) {
          toast({
            title: "Error",
            description: "Failed to register for notifications",
            variant: "destructive",
          });
          return false;
        }
      }

      setHasPermission(true);
      toast({
        title: "Notifications Enabled",
        description: "You'll receive cleaning reminders and app updates",
      });
      return true;
    } catch (error) {
      console.error('Error requesting Expo permissions:', error);
      toast({
        title: "Error",
        description: "Failed to enable notifications",
        variant: "destructive",
      });
      setHasPermission(false);
      return false;
    }
  };

  const showNotification = async (title: string, body: string, data?: any) => {
    const hasPerms = await checkPermissions();
    if (!hasPerms) {
      console.log('No notification permissions, skipping notification');
      return;
    }

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        console.log('User not logged in, skipping notification');
        return;
      }

      // Send notification via Expo edge function
      const { error } = await supabase.functions.invoke('send-expo-notification', {
        body: {
          userId: user.id,
          title,
          body,
          data: {
            type: 'test',
            ...data
          }
        }
      });

      if (error) {
        console.error('Error sending notification:', error);
        toast({
          title: "Error",
          description: "Failed to send notification",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error('Error showing notification:', error);
      toast({
        title: "Error",
        description: "Failed to send notification",
        variant: "destructive",
      });
    }
  };

  const sendTestNotification = async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      toast({
        title: "Error",
        description: "Must be logged in to send test notification",
        variant: "destructive",
      });
      return false;
    }

    return await expoNotificationService.sendTestNotification();
  };

  return {
    hasPermission,
    userTimezone,
    requestPermissions,
    showNotification,
    checkPermissions,
    sendTestNotification,
  };
};