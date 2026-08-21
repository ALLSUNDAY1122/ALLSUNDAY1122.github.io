import { Text, type ColorValue } from 'react-native';
import { Tabs } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors } from '@/src/components/ui';

function TabGlyph({ glyph, color }: { glyph: string; color: ColorValue }) {
  return <Text style={{ color, fontSize: 18, fontWeight: '900' }}>{glyph}</Text>;
}

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
          height: 58 + insets.bottom,
          paddingBottom: Math.max(insets.bottom, 8),
          paddingTop: 6
        }
      }}
    >
      <Tabs.Screen
        name="cards"
        options={{
          title: 'フォルダ',
          tabBarIcon: ({ color }) => <TabGlyph glyph="▣" color={color} />
        }}
      />
      <Tabs.Screen
        name="create"
        options={{
          title: '作る',
          tabBarIcon: ({ color }) => <TabGlyph glyph="＋" color={color} />
        }}
      />
      <Tabs.Screen
        name="study"
        options={{
          title: '学習',
          tabBarIcon: ({ color }) => <TabGlyph glyph="▶" color={color} />
        }}
      />
      <Tabs.Screen
        name="records"
        options={{
          title: '記録',
          tabBarIcon: ({ color }) => <TabGlyph glyph="▤" color={color} />
        }}
      />
    </Tabs>
  );
}