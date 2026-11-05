import 'server-only';import Stripe from 'stripe';import {createClient} from '@supabase/supabase-js';
export function stripe(){const key=process.env.STRIPE_SECRET_KEY;if(!key?.startsWith('sk_test_'))throw Error('Stripe test environment required');return new Stripe(key)}
export function database(){const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!url||!key)throw Error('Database not configured');return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}})}
