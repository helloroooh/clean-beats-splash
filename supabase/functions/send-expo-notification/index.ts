import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ExpoNotificationRequest {
  userId?: string;
  userIds?: string[];
  topic?: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  priority?: 'default' | 'normal' | 'high';
  sound?: 'default' | null;
  badge?: number;
}

interface ExpoMessage {
  to?: string | string[];
  title: string;
  body: string;
  data?: Record<string, any>;
  sound?: 'default' | null;
  badge?: number;
  priority?: 'default' | 'normal' | 'high';
  channelId?: string;
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const handler = async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const expoRequest: ExpoNotificationRequest = await req.json();
    console.log('📱 Expo notification request:', expoRequest);

    const results = [];
    
    if (expoRequest.topic) {
      // Send to all users (topic functionality)
      const result = await sendToAllUsers(expoRequest);
      results.push(result);
    } else if (expoRequest.userId) {
      // Send to single user
      const result = await sendToUser(expoRequest.userId, expoRequest);
      results.push(result);
    } else if (expoRequest.userIds && expoRequest.userIds.length > 0) {
      // Send to multiple users
      for (const userId of expoRequest.userIds) {
        const result = await sendToUser(userId, expoRequest);
        results.push(result);
      }
    } else {
      throw new Error('No valid recipient specified (userId, userIds, or topic)');
    }

    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`📊 Expo notifications sent: ${successCount} successful, ${failureCount} failed`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Sent ${successCount} notifications, ${failureCount} failed`,
        results: results
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    );

  } catch (error) {
    console.error('❌ Error sending Expo notification:', error);
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    );
  }
};

async function sendToAllUsers(expoRequest: ExpoNotificationRequest) {
  try {
    // Get all active Expo tokens
    const { data: tokens, error } = await supabase
      .from('fcm_tokens')
      .select('*')
      .like('platform', 'expo-%')
      .eq('is_active', true);

    if (error) {
      console.error('❌ Error fetching Expo tokens:', error);
      return { success: false, error: 'Failed to fetch tokens' };
    }

    if (!tokens || tokens.length === 0) {
      console.log('⚠️ No active Expo tokens found');
      return { success: false, error: 'No active tokens found' };
    }

    const tokenList = tokens.map(t => t.token);
    return await sendExpoNotification(tokenList, expoRequest);

  } catch (error) {
    console.error('❌ Error sending to all users:', error);
    return { success: false, error: error.message };
  }
}

async function sendToUser(userId: string, expoRequest: ExpoNotificationRequest) {
  try {
    // Get user's active Expo tokens
    const { data: tokens, error } = await supabase
      .from('fcm_tokens')
      .select('*')
      .eq('user_id', userId)
      .like('platform', 'expo-%')
      .eq('is_active', true);

    if (error) {
      console.error('❌ Error fetching user tokens:', error);
      return { success: false, error: 'Failed to fetch user tokens' };
    }

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ No active Expo tokens found for user ${userId}`);
      return { success: false, error: 'No active tokens for user' };
    }

    const tokenList = tokens.map(t => t.token);
    const result = await sendExpoNotification(tokenList, expoRequest);

    // Track delivery status
    for (const tokenRecord of tokens) {
      await supabase
        .from('notification_deliveries')
        .insert({
          user_id: userId,
          notification_type: expoRequest.data?.type || 'unknown',
          platform: tokenRecord.platform,
          status: result.success ? 'sent' : 'failed',
          error_message: result.success ? null : result.error,
          metadata: {
            expo_message_id: result.messageId,
            timestamp: new Date().toISOString()
          }
        });
    }

    return result;

  } catch (error) {
    console.error('❌ Error in sendToUser:', error);
    return { success: false, error: error.message };
  }
}

async function sendExpoNotification(tokens: string | string[], expoRequest: ExpoNotificationRequest) {
  try {
    const message: ExpoMessage = {
      to: tokens,
      title: expoRequest.title,
      body: expoRequest.body,
      data: expoRequest.data || {},
      sound: expoRequest.sound || 'default',
      priority: expoRequest.priority || 'normal',
      channelId: 'default'
    };

    if (expoRequest.badge !== undefined) {
      message.badge = expoRequest.badge;
    }

    console.log('📤 Sending to Expo Push API:', message);

    const response = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Accept-encoding': 'gzip, deflate',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    });

    const result = await response.json();
    
    if (!response.ok) {
      console.error('❌ Expo API error:', result);
      return { success: false, error: result.message || 'Unknown Expo error' };
    }

    console.log('✅ Expo notification sent successfully:', result);
    
    // Handle Expo push tickets
    if (result.data && Array.isArray(result.data)) {
      const tickets = result.data;
      const errors = tickets.filter(ticket => ticket.status === 'error');
      
      if (errors.length > 0) {
        console.warn('⚠️ Some notifications failed:', errors);
        return { 
          success: tickets.some(ticket => ticket.status === 'ok'),
          error: `${errors.length} notifications failed`,
          tickets
        };
      }
    }

    return { 
      success: true, 
      messageId: result.data?.[0]?.id || 'unknown',
      tickets: result.data 
    };

  } catch (error) {
    console.error('❌ Error sending Expo notification:', error);
    return { success: false, error: error.message };
  }
}

serve(handler);