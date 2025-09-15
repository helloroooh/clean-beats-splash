import { Settings, Music, Bell, Users, Calendar, Headphones, TrendingUp, Trophy, Flame, Crown, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import { useNavigate } from "react-router-dom";
import { useToast } from "@/hooks/use-toast";
import { useEffect, useState } from "react";
import UserSearch from "@/components/UserSearch";
import { notificationService } from "@/services/notificationService";
import { ExpoNotificationTest } from "@/components/ExpoNotificationTest";

interface Equipment {
  id: string;
  name: string;
  current_streak: number;
  best_streak: number;
}

interface TopStreak {
  user_id: string;
  username: string;
  display_name: string;
  avatar_url: string;
  best_streak: number;
  equipment_name: string;
}

const Home = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [user, setUser] = useState<any>(null);
  const [greeting, setGreeting] = useState("");
  const [unreadNotifications, setUnreadNotifications] = useState(0);
  const [bestEquipment, setBestEquipment] = useState<Equipment | null>(null);
  const [topStreaks, setTopStreaks] = useState<TopStreak[]>([]);
  const [userRank, setUserRank] = useState<number>(0);
  const [totalUsers, setTotalUsers] = useState<number>(0);

  useEffect(() => {
    getCurrentUser();
    fetchUnreadNotifications();
    fetchDashboardData();
    
    // Initialize notifications with error handling
    const initNotifications = async () => {
      try {
        await initializeNotifications();
      } catch (error) {
        console.warn('⚠️ Notifications not available in this environment:', error);
      }
    };
    initNotifications();

    // Set up real-time subscription for notifications
    const setupRealtimeNotifications = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return null;

      console.log('Setting up real-time notifications for user:', user.id);
      
      const channel = supabase
        .channel('notifications-changes')
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${user.id}`
          },
          (payload) => {
            console.log('New notification received:', payload);
            // Update unread count
            setUnreadNotifications(prev => prev + 1);
            
            // Check and show desktop notification
            console.log('Checking notification permission:', Notification?.permission);
            console.log('Notification API available:', 'Notification' in window);
            
            if ('Notification' in window) {
              console.log('Current permission status:', Notification.permission);
              
              if (Notification.permission === 'granted') {
                const notificationData = payload.new;
                console.log('Creating desktop notification with data:', notificationData);
                
                try {
                  const notification = new Notification(notificationData.title || 'Clean Beats 🎵', {
                    body: notificationData.message,
                    icon: '/favicon.ico',
                    tag: `notification-${notificationData.id}`,
                    requireInteraction: true,
                    silent: false,
                    badge: '/favicon.ico'
                  });
                  
                  notification.onclick = () => {
                    console.log('Desktop notification clicked');
                    window.focus();
                    navigate('/notifications');
                    notification.close();
                  };
                  
                  notification.onerror = (error) => {
                    console.error('Desktop notification error:', error);
                  };
                  
                  notification.onshow = () => {
                    console.log('Desktop notification shown successfully');
                  };
                  
                  notification.onclose = () => {
                    console.log('Desktop notification closed');
                  };
                  
                  // Auto close after 8 seconds
                  setTimeout(() => {
                    console.log('Auto-closing desktop notification');
                    notification.close();
                  }, 8000);
                  
                  console.log('Desktop notification created successfully');
                } catch (error) {
                  console.error('Failed to create desktop notification:', error);
                }
              } else {
                console.log('Desktop notifications not permitted. Current status:', Notification.permission);
                console.log('Please grant notification permissions to see desktop notifications');
              }
            } else {
              console.log('Desktop notifications not supported in this browser');
            }
          }
        )
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'notifications',
            filter: `user_id=eq.${user.id}`
          },
          (payload) => {
            console.log('Notification updated:', payload);
            // If notification was marked as read, decrease unread count
            if (payload.old.read === false && payload.new.read === true) {
              setUnreadNotifications(prev => Math.max(0, prev - 1));
            }
          }
        )
        .subscribe((status) => {
          console.log('Notifications realtime status:', status);
        });

      return channel;
    };

    // Setup realtime and cleanup
    let channel: any = null;
    setupRealtimeNotifications().then(ch => {
      channel = ch;
    });

    return () => {
      if (channel) {
        supabase.removeChannel(channel);
      }
    };
  }, [navigate]);

  const initializeNotifications = async () => {
    try {
      await notificationService.initializePushNotifications();
    } catch (error) {
      console.warn('⚠️ Push notifications not available:', error);
      // Don't throw error to prevent app crashes
    }
  };

  const handleTestNotification = async () => {
    console.log('Test notification button clicked');
    
    try {
      // Always try to request permissions first, regardless of current status
      if ('Notification' in window) {
        console.log('Current notification permission:', Notification.permission);
        
        // For denied permissions, we'll still try to request (some browsers allow re-prompting)
        if (Notification.permission === 'denied') {
          toast({
            title: "Notifications Currently Blocked",
            description: "Trying to request permissions again. If no dialog appears, please manually enable notifications in your browser settings.",
          });
        }
        
        // Always request permission on button click to trigger the browser dialog
        console.log('Requesting notification permission...');
        try {
          const permission = await Notification.requestPermission();
          console.log('Permission result:', permission);
          
          if (permission === 'granted') {
            toast({
              title: "Notifications Enabled! ✅",
              description: "Great! Notifications are now enabled. Testing notification...",
            });
          } else if (permission === 'denied') {
            toast({
              title: "Notifications Blocked",
              description: "You blocked notifications. To enable: click the 🔒 icon in address bar → change notifications to 'Allow' → refresh page.",
              variant: "destructive"
            });
          } else {
            toast({
              title: "Permission Not Granted",
              description: "Notification permission was not granted. Please try again.",
              variant: "destructive"
            });
          }
        } catch (error) {
          console.error('Error requesting permission:', error);
          toast({
            title: "Permission Request Failed",
            description: "Could not request notification permissions. Please enable them manually in browser settings.",
            variant: "destructive"
          });
        }
      } else {
        toast({
          title: "Notifications Not Supported",
          description: "Your browser doesn't support notifications.",
          variant: "destructive"
        });
        return;
      }

      // Send the test notification (both in-app and system if permitted)
      console.log('Sending test notification...');
      const success = await notificationService.sendTestNotification();
      console.log('Test notification result:', success);
      
      if (success) {
        toast({
          title: "Test Notification Sent! 🎵",
          description: "Check your notifications page and system notifications.",
        });
      } else {
        toast({
          title: "Partial Success",
          description: "In-app notification created, but system notification may be blocked.",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error('Error in handleTestNotification:', error);
      toast({
        title: "Error",
        description: `Failed to send test notification: ${error}`,
        variant: "destructive"
      });
    }
  };

  const getCurrentUser = async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      setUser(user);
      // Get user profile for display name
      const { data: profile } = await supabase
        .from('profiles')
        .select('display_name, username')
        .eq('user_id', user.id)
        .single();
      
      if (profile) {
        setUser({ ...user, profile });
      }
    }
  };

  const fetchUnreadNotifications = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { count } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('read', false);

      setUnreadNotifications(count || 0);
    } catch (error) {
      console.error('Error fetching unread notifications:', error);
    }
  };

  const fetchDashboardData = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      // Get user's best equipment
      const { data: equipment } = await supabase
        .from('equipment')
        .select('id, name, current_streak, best_streak')
        .eq('user_id', user.id)
        .order('best_streak', { ascending: false })
        .limit(1);

      if (equipment && equipment.length > 0) {
        setBestEquipment(equipment[0]);
      }

      // Get global top streaks from all users
      const { data: streaks } = await supabase
        .rpc('get_global_top_streaks', { 
          p_limit: 5 
        });

      setTopStreaks(streaks || []);

      // Get user's global rank
      const { data: rankData } = await supabase
        .rpc('get_user_global_rank', { 
          p_user_id: user.id 
        });

      if (rankData && rankData.length > 0) {
        setUserRank(rankData[0].rank_position);
        setTotalUsers(rankData[0].total_users);
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    }
  };

  // Set greeting based on time
  useEffect(() => {
    const hour = new Date().getHours();
    if (hour < 12) {
      setGreeting("Good Morning");
    } else if (hour < 17) {
      setGreeting("Good Afternoon");
    } else {
      setGreeting("Good Evening");
    }
  }, []);

  const getUserDisplayName = () => {
    return user?.profile?.display_name || user?.profile?.username || "User";
  };

  const shortcutCards = [
    {
      title: "Community",
      description: "See posts from friends",
      icon: Users,
      route: "/community",
      color: "text-blue-500"
    },
    {
      title: "Equipment",
      description: "Manage your gear",
      icon: Headphones,
      route: "/equipment", 
      color: "text-green-500"
    },
    {
      title: "Calendar",
      description: "Schedule events",
      icon: Calendar,
      route: "/calendar",
      color: "text-purple-500"
    },
    {
      title: "Notifications",
      description: "Check updates",
      icon: Bell,
      route: "/notifications",
      color: "text-orange-500",
      badge: unreadNotifications
    }
  ];

  return (
    <div className="min-h-screen bg-background text-foreground gradient-hero">
      <div className="container mx-auto p-4 max-w-md">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-accent/20 rounded-full flex items-center justify-center animate-glow">
              <Music className="w-6 h-6 text-accent" />
            </div>
          </div>
          <Button
            onClick={() => navigate("/settings")}
            variant="outline"
            size="sm"
            className="gap-2"
          >
            <Settings className="w-4 h-4" />
            Settings
          </Button>
        </div>

        {/* Greeting */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold">
            {greeting}, {getUserDisplayName()}! 👋
          </h1>
          <p className="text-muted-foreground">Welcome to your dashboard</p>
        </div>

        {/* Search Bar */}
        <div className="mb-6">
          <UserSearch
            placeholder="Search users..."
            className="w-full"
          />
        </div>

        {/* Notification Testing */}
        <div className="mb-6">
          <ExpoNotificationTest />
        </div>

        {/* Shortcut Cards */}
        <div className="grid grid-cols-2 gap-3 mb-6">
          {shortcutCards.map((card) => (
            <Card 
              key={card.title} 
              className="glass-card cursor-pointer hover:scale-105 transition-transform"
              onClick={() => navigate(card.route)}
            >
              <CardContent className="p-4 text-center">
                <div className="relative">
                  <card.icon className={`w-8 h-8 mx-auto mb-2 ${card.color}`} />
                  {card.badge && card.badge > 0 && (
                    <Badge className="absolute -top-1 -right-1 w-5 h-5 p-0 text-xs">
                      {card.badge > 9 ? '9+' : card.badge}
                    </Badge>
                  )}
                </div>
                <h3 className="font-semibold text-sm">{card.title}</h3>
                <p className="text-xs text-muted-foreground">{card.description}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* User's Best Equipment */}
        {bestEquipment && (
          <Card className="glass-card mb-6">
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center gap-2 text-lg">
                <Trophy className="w-5 h-5 text-yellow-500" />
                Your Best Streak
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold">{bestEquipment.name}</h3>
                  <p className="text-sm text-muted-foreground">
                    Current: {bestEquipment.current_streak} days
                  </p>
                </div>
                <div className="text-right">
                  <div className="flex items-center gap-1">
                    <Flame className="w-4 h-4 text-orange-500" />
                    <span className="text-xl font-bold">{bestEquipment.best_streak}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">best streak</p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Global Ranking */}
        {userRank > 0 && (
          <Card className="glass-card mb-6">
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center gap-2 text-lg">
                <TrendingUp className="w-5 h-5 text-accent" />
                Your Global Rank
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-center">
                <div className="flex items-center justify-center gap-2 mb-2">
                  <Crown className="w-6 h-6 text-yellow-500" />
                  <span className="text-2xl font-bold">#{userRank}</span>
                </div>
                <p className="text-sm text-muted-foreground">
                  out of {totalUsers} users
                </p>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Top Streaks Leaderboard */}
        {topStreaks.length > 0 && (
          <Card className="glass-card">
            <CardHeader className="pb-3">
              <CardTitle className="flex items-center gap-2 text-lg">
                <Users className="w-5 h-5 text-blue-500" />
                Top Streaks
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {topStreaks.map((streak, index) => (
                <div 
                  key={streak.user_id} 
                  className="flex items-center gap-3 p-2 rounded-lg bg-accent/5 cursor-pointer hover:bg-accent/10 transition-colors"
                  onClick={() => navigate(`/profile/${streak.user_id}`)}
                >
                  <div className="flex items-center gap-2 min-w-0 flex-1">
                    <span className="text-sm font-bold text-muted-foreground w-4">
                      #{index + 1}
                    </span>
                    <Avatar className="w-8 h-8">
                      <AvatarImage src={streak.avatar_url} />
                      <AvatarFallback>
                        <User className="w-4 h-4" />
                      </AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold text-sm truncate">
                        {streak.display_name || streak.username}
                      </p>
                      <p className="text-xs text-muted-foreground truncate">
                        {streak.equipment_name}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-1">
                    <Flame className="w-4 h-4 text-orange-500" />
                    <span className="font-bold">{streak.best_streak}</span>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
};

export default Home;