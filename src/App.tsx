import { useEffect } from "react";
import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";
import { ThemeProvider } from "next-themes";
import { notificationService } from "./services/notificationService";
import Index from "./pages/Index";
import Auth from "./pages/Auth";
import Home from "./pages/Home";
import Equipment from "./pages/Equipment";
import Calendar from "./pages/Calendar";
import Community from "./pages/Community";
import Profile from "./pages/Profile";
import Settings from "./pages/Settings";
import TestNotifications from "./pages/TestNotifications";
import Notifications from "./pages/Notifications";
import NotFound from "./pages/NotFound";
import BottomNavigation from "./components/BottomNavigation";
import NotificationPermissionBanner from "./components/NotificationPermissionBanner";
import PWAInstallPrompt from "./components/PWAInstallPrompt";
import PWAUpdatePrompt from "./components/PWAUpdatePrompt";

const queryClient = new QueryClient();

const AppContent = () => {
  const location = useLocation();
  const hideNavbar = location.pathname === '/auth' || location.pathname === '/';
  
  return (
    <div className="pb-16">
      <Routes>
        <Route path="/" element={<Index />} />
        <Route path="/auth" element={<Auth />} />
        <Route path="/home" element={<Home />} />
        <Route path="/equipment" element={<Equipment />} />
        <Route path="/calendar" element={<Calendar />} />
        <Route path="/community" element={<Community />} />
        <Route path="/profile" element={<Profile />} />
        <Route path="/profile/:userId" element={<Profile />} />
        <Route path="/notifications" element={<Notifications />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/test-notifications" element={<TestNotifications />} />
        {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
        <Route path="*" element={<NotFound />} />
      </Routes>
      {!hideNavbar && <BottomNavigation />}
      <NotificationPermissionBanner />
      <PWAInstallPrompt />
      <PWAUpdatePrompt />
    </div>
  );
};

const App = () => {
  useEffect(() => {
    const initializeNotifications = async () => {
      console.log('App: Initializing notifications...');
      
      try {
        // Initialize push notifications setup
        await notificationService.initializePushNotifications();
        console.log('App: Push notifications initialized');
        
        // Set up notification listeners for real-time push notifications
        await notificationService.setupNotificationListeners();
        console.log('App: Notification listeners set up');
        
      } catch (error) {
        console.error('App: Error initializing notifications:', error);
        // Don't crash the app if notifications fail to initialize
        console.warn('⚠️ Continuing without notifications');
      }
    };
    
    initializeNotifications();

    // Cleanup on unmount
    return () => {
      notificationService.cleanupListeners();
    };
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider attribute="class" defaultTheme="dark" enableSystem>
        <TooltipProvider>
          <Toaster />
          <Sonner />
          <BrowserRouter>
            <AppContent />
          </BrowserRouter>
        </TooltipProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
};

export default App;
