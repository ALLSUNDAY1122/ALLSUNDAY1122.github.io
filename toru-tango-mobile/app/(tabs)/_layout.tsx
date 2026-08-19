import { Tabs } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors } from '@/src/components/ui';

export default function TabLayout() {
  const insets = useSafeAreaInsets();
  return (
    <Tabs
      initialRouteName="cards"
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.muted,
        tabBarLabelStyle: { fontSize: 12, fontWeight: '800' },
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          height: 56 + insets.bottom,
          paddingBottom: Math.max(insets.bottom, 8),
          paddingTop: 7
        }
      }}
    >
      <Tabs.Screen name="cards" options={{ title: 'フォルダ' }} />
      <Tabs.Screen name="create" options={{ title: '作る' }} />
      <Tabs.Screen name="study" options={{ title: '学習' }} />
      <Tabs.Screen name="records" options={{ title: '記録' }} />
    </Tabs>
  );
}
