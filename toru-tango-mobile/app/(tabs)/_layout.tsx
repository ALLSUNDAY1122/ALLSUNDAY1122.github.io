import { Tabs } from 'expo-router';
import { colors } from '@/src/components/ui';

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted,
        tabBarLabelStyle: { fontSize: 12, fontWeight: '700' },
        tabBarStyle: { height: 62, paddingBottom: 8, paddingTop: 6 }
      }}
    >
      <Tabs.Screen name="create" options={{ title: '作る' }} />
      <Tabs.Screen name="cards" options={{ title: '単語帳' }} />
      <Tabs.Screen name="study" options={{ title: '学習' }} />
      <Tabs.Screen name="records" options={{ title: '記録' }} />
    </Tabs>
  );
}
