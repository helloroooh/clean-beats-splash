import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { expoNotificationService } from '@/services/expoNotificationService';
import { notificationService } from '@/services/notificationService';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { Bell, Smartphone, Monitor, Tablet } from 'lucide-react';
import * as Device from 'expo-device';

export const TestNotifications = () => {
  const [loading, setLoading] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  const [user, setUser] = useState<any>(null);
  const [platformInfo, setPlatformInfo] = useState({
    platform: 'expo',
    isDevice: false,
    serviceType: 'Expo Notifications'
  });
  

  useEffect(() => {
    const detectPlatform = () => {
      const isDevice = Device.isDevice;
      
      setPlatformInfo({
        platform: 'expo',
        isDevice,
        serviceType: 'Expo Notifications'
      });
      
      console.log('🔍 Expo Platform Detection:', {
        'Is Device': isDevice,
        'Platform': 'expo',
        'Service Type': 'Expo Notifications'
      });
    };

    detectPlatform();
  }, []);

  const checkAuthAndToken = async () => {
    console.log('TestNotifications: Checking auth and token...');
    const { data: { user: currentUser } } = await supabase.auth.getUser();
    if (!currentUser) {
      console.error('TestNotifications: No authenticated user');
      toast.error('Please sign in to test notifications');
      return null;
    }
    console.log('TestNotifications: User authenticated:', currentUser.id);
    setUser(currentUser);

    // Get Expo push token
    console.log('TestNotifications: Getting Expo push token...');
    const expoToken = expoNotificationService.getToken();
    if (!expoToken) {
      console.error('TestNotifications: Failed to get Expo token');
      toast.error('Failed to get Expo token. Initialize notifications first.');
      return null;
    }
    console.log('TestNotifications: Expo token obtained successfully');
    setToken(expoToken);
    return { user: currentUser, token: expoToken };
  };

  const initializeNotifications = async () => {
    setLoading(true);
    try {
      console.log('Initializing Expo notifications...');
      
      // Initialize Expo notification service
      const initialized = await expoNotificationService.initialize();
      if (!initialized) {
        toast.error('Failed to initialize Expo notification service');
        return;
      }

      // Get user for token saving
      const { user: currentUser } = await checkAuthAndToken() || {};
      if (!currentUser) return;

      toast.success('Expo push notifications initialized successfully!');
    } catch (error) {
      console.error('Error initializing notifications:', error);
      toast.error('Failed to initialize notifications');
    } finally {
      setLoading(false);
    }
  };

  const sendTestNotification = async () => {
    setLoading(true);
    try {
      const { user: currentUser } = await checkAuthAndToken() || {};
      if (!currentUser) return;

      const { error } = await supabase.functions.invoke('send-expo-notification', {
        body: {
          userId: currentUser.id,
          title: 'Test Notification 🧽',
          body: 'This is a test notification from Clean Beats!',
          data: {
            type: 'test',
            timestamp: new Date().toISOString(),
            action: 'open_app'
          },
          priority: 'high'
        }
      });

      if (error) {
        console.error('Error sending test notification:', error);
        toast.error(`Failed to send test notification: ${error.message}`);
        return;
      }

      toast.success('Test notification sent successfully!');
    } catch (error) {
      console.error('Error sending test notification:', error);
      toast.error('Failed to send test notification');
    } finally {
      setLoading(false);
    }
  };

  const sendTopicNotification = async () => {
    setLoading(true);
    try {
      const { error } = await supabase.functions.invoke('send-expo-notification', {
        body: {
          topic: 'all_users',
          title: 'Community Update 🎉',
          body: 'Check out the latest updates in Clean Beats!',
          data: {
            type: 'community_update',
            timestamp: new Date().toISOString()
          },
          priority: 'normal'
        }
      });

      if (error) {
        console.error('Error sending topic notification:', error);
        toast.error(`Failed to send topic notification: ${error.message}`);
        return;
      }

      toast.success('Topic notification sent successfully!');
    } catch (error) {
      console.error('Error sending topic notification:', error);
      toast.error('Failed to send topic notification');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6 p-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Bell className="h-5 w-5" />
            Push Notification Testing
          </CardTitle>
          <CardDescription>
            Test Firebase Cloud Messaging across different platforms
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Platform Info */}
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Smartphone className="h-4 w-4" />
            Platform: {platformInfo.platform}
          </div>

          {/* Service Type */}
          <div className="text-sm text-muted-foreground">
            Service: {platformInfo.serviceType}
          </div>

          {/* Status */}
          <div className="space-y-2">
            <div className="text-sm">
              <span className="font-medium">Service Status:</span>{' '}
              <span className={
                (platformInfo.isDevice || expoNotificationService.isServiceInitialized()) 
                  ? 'text-green-600' : 'text-red-600'
              }>
                {platformInfo.isDevice 
                  ? 'Physical Device Ready' 
                  : (expoNotificationService.isServiceInitialized() ? 'Expo Initialized' : 'Not Initialized')
                }
              </span>
            </div>
            {token && (
              <div className="text-sm">
                <span className="font-medium">Token:</span>{' '}
                <code className="text-xs bg-muted p-1 rounded">
                  {token.substring(0, 20)}...
                </code>
              </div>
            )}
          </div>

          {/* Action Buttons */}
          <div className="space-y-3">
            <Button 
              onClick={initializeNotifications} 
              disabled={loading}
              className="w-full"
              variant={
                (platformInfo.isDevice || expoNotificationService.isServiceInitialized()) 
                  ? "outline" : "default"
              }
            >
              {loading 
                ? 'Initializing...' 
                : 'Initialize Expo Notifications & Request Permissions'
              }
            </Button>

            <Button 
              onClick={sendTestNotification} 
              disabled={
                loading || 
                !expoNotificationService.isServiceInitialized()
              }
              className="w-full"
              variant="secondary"
            >
              {loading ? 'Sending...' : 'Send Test Notification (Personal)'}
            </Button>

            <Button 
              onClick={sendTopicNotification} 
              disabled={loading}
              className="w-full"
              variant="outline"
            >
              {loading ? 'Sending...' : 'Send Topic Notification (Broadcast)'}
            </Button>
          </div>

          {/* Instructions */}
          <div className="mt-6 p-4 bg-muted rounded-lg space-y-2">
            <h4 className="font-medium">Testing Instructions:</h4>
            <ol className="text-sm space-y-1 list-decimal list-inside">
              <li>Click "Initialize" to set up Expo notifications</li>
              <li>Allow permissions when prompted</li>
              <li>Send a test notification to see it in action</li>
              <li>Check console for detailed logs</li>
              {platformInfo.isDevice ? (
                <li>Physical device detected - using Expo Push Notifications</li>
              ) : (
                <li>Simulator/Web detected - limited notification support</li>
              )}
            </ol>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};