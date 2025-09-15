import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Bell, Smartphone, Wifi, WifiOff } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useEffect, useState } from 'react';
import { expoNotificationService } from '@/services/expoNotificationService';
import * as Device from 'expo-device';

export const ExpoNotificationTest = () => {
  const { toast } = useToast();
  const [hasPermissions, setHasPermissions] = useState(false);
  const [expoPushToken, setExpoPushToken] = useState<string | null>(null);
  const [isPhysicalDevice, setIsPhysicalDevice] = useState(false);

  useEffect(() => {
    checkDeviceAndPermissions();
  }, []);

  const checkDeviceAndPermissions = async () => {
    try {
      const isDevice = Device.isDevice;
      setIsPhysicalDevice(isDevice);
      
      if (isDevice) {
        const hasPerms = await expoNotificationService.requestPermissions();
        setHasPermissions(hasPerms);
        
        if (hasPerms) {
          const token = expoNotificationService.getToken();
          setExpoPushToken(token);
        }
      }
    } catch (error) {
      console.error('Error checking device and permissions:', error);
    }
  };

  const initializeNotifications = async () => {
    try {
      const initialized = await expoNotificationService.initialize();
      if (initialized) {
        setHasPermissions(true);
        const token = expoNotificationService.getToken();
        setExpoPushToken(token);
        
        toast({
          title: "Success",
          description: "Expo notifications initialized successfully!",
        });
      } else {
        toast({
          title: "Error",
          description: "Failed to initialize Expo notifications",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error('Error initializing notifications:', error);
      toast({
        title: "Error",
        description: "Failed to initialize notifications",
        variant: "destructive",
      });
    }
  };

  const sendTestNotification = async () => {
    try {
      const success = await expoNotificationService.sendTestNotification();
      if (success) {
        toast({
          title: "Success",
          description: "Test notification sent successfully!",
        });
      } else {
        toast({
          title: "Error",
          description: "Failed to send test notification",
          variant: "destructive",
        });
      }
    } catch (error) {
      console.error('Error sending test notification:', error);
      toast({
        title: "Error",
        description: "Failed to send test notification",
        variant: "destructive",
      });
    }
  };

  return (
    <Card className="glass-card">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Bell className="w-5 h-5" />
          Expo Notification Testing
          <Badge variant={isPhysicalDevice ? "default" : "secondary"}>
            {isPhysicalDevice ? "Physical Device" : "Simulator/Web"}
          </Badge>
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Device Status */}
        <div className="flex items-center gap-2 text-sm">
          {isPhysicalDevice ? (
            <>
              <Smartphone className="w-4 h-4 text-green-500" />
              <span>Running on physical device</span>
            </>
          ) : (
            <>
              <Wifi className="w-4 h-4 text-orange-500" />
              <span>Running on simulator/web (push notifications limited)</span>
            </>
          )}
        </div>

        {/* Permission Status */}
        <div className="flex items-center gap-2 text-sm">
          {hasPermissions ? (
            <>
              <Bell className="w-4 h-4 text-green-500" />
              <span>Notification permissions granted</span>
            </>
          ) : (
            <>
              <WifiOff className="w-4 h-4 text-red-500" />
              <span>Notification permissions needed</span>
            </>
          )}
        </div>

        {/* Expo Push Token Status */}
        {expoPushToken && (
          <div className="text-xs text-muted-foreground">
            Expo Push Token: {expoPushToken.substring(0, 40)}...
          </div>
        )}

        {/* Test Buttons */}
        <div className="space-y-2">
          <Button
            onClick={initializeNotifications}
            variant="outline"
            className="w-full"
          >
            <Bell className="w-4 h-4 mr-2" />
            Initialize Expo Notifications
          </Button>
          
          <Button
            onClick={sendTestNotification}
            variant="outline"
            className="w-full"
            disabled={!hasPermissions || !isPhysicalDevice}
          >
            <Smartphone className="w-4 h-4 mr-2" />
            Send Test Push Notification
          </Button>
        </div>

        {/* Instructions */}
        <div className="text-xs text-muted-foreground">
          {isPhysicalDevice ? (
            <p>
              Expo notifications work on physical devices. Test notifications will appear in your device's notification center.
            </p>
          ) : (
            <p>
              Push notifications require a physical device. Local notifications may work in simulators.
            </p>
          )}
        </div>
      </CardContent>
    </Card>
  );
};