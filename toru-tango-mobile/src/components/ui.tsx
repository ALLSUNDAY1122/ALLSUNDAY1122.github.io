import type { PropsWithChildren, ReactNode } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  type TextInputProps,
  View
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export const colors = {
  background: '#f7f9fb',
  surface: '#ffffff',
  surfaceMuted: '#f0f7f8',
  text: '#17202a',
  muted: '#6b7280',
  primary: '#14a9bf',
  primaryDark: '#087f91',
  primarySoft: '#e7f8fb',
  border: '#e4e7ec',
  danger: '#c62828',
  dangerSoft: '#fff1f2',
  success: '#16803c',
  successSoft: '#edf9f1',
  warning: '#e58b11',
  warningSoft: '#fff7e8'
};

export function Page({ children }: PropsWithChildren) {
  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={styles.page}
        showsVerticalScrollIndicator={false}
      >
        {children}
      </ScrollView>
    </SafeAreaView>
  );
}

export function Section({
  title,
  children,
  right
}: PropsWithChildren<{ title: string; right?: ReactNode }>) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>{title}</Text>
        {right}
      </View>
      {children}
    </View>
  );
}

type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'success';

export function AppButton({
  label,
  onPress,
  variant = 'primary',
  disabled = false
}: {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  disabled?: boolean;
}) {
  const variantStyle = {
    primary: styles.buttonPrimary,
    secondary: styles.buttonSecondary,
    danger: styles.buttonDanger,
    success: styles.buttonSuccess
  }[variant];

  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        variantStyle,
        pressed && !disabled && styles.pressed,
        disabled && styles.disabled
      ]}
    >
      <Text
        style={[
          styles.buttonText,
          variant === 'secondary' && styles.secondaryButtonText
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

export function Field({
  label,
  multiline,
  ...props
}: TextInputProps & { label: string }) {
  return (
    <View style={styles.fieldWrap}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        {...props}
        multiline={multiline}
        placeholderTextColor="#98a2b3"
        style={[styles.input, multiline && styles.multiline, props.style]}
      />
    </View>
  );
}

export function ChoiceRow<T extends string>({
  value,
  options,
  onChange
}: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (value: T) => void;
}) {
  return (
    <View style={styles.choiceRow}>
      {options.map((option) => (
        <Pressable
          key={option.value}
          accessibilityRole="button"
          accessibilityState={{ selected: value === option.value }}
          onPress={() => onChange(option.value)}
          style={[
            styles.choice,
            value === option.value && styles.choiceActive
          ]}
        >
          <Text
            style={[
              styles.choiceText,
              value === option.value && styles.choiceTextActive
            ]}
          >
            {option.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

export function EmptyState({ children }: PropsWithChildren) {
  return <Text style={styles.empty}>{children}</Text>;
}

export function MutedText({ children }: PropsWithChildren) {
  return <Text style={styles.muted}>{children}</Text>;
}

export const commonStyles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8
  },
  title: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '800',
    letterSpacing: -0.4
  },
  subtitle: {
    color: colors.muted,
    lineHeight: 20,
    marginTop: 4,
    marginBottom: 12
  }
});

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  page: { padding: 16, paddingBottom: 44 },
  section: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 20,
    borderWidth: 1,
    padding: 16,
    marginBottom: 14,
    gap: 12,
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.04,
    shadowRadius: 10,
    elevation: 1
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  sectionTitle: { color: colors.text, fontSize: 18, fontWeight: '800' },
  button: {
    minHeight: 46,
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 14,
    paddingHorizontal: 15,
    paddingVertical: 11
  },
  buttonPrimary: { backgroundColor: colors.primary },
  buttonSecondary: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderWidth: 1
  },
  buttonDanger: { backgroundColor: colors.danger },
  buttonSuccess: { backgroundColor: colors.success },
  buttonText: { color: '#ffffff', fontWeight: '800' },
  secondaryButtonText: { color: colors.text },
  pressed: { opacity: 0.72 },
  disabled: { opacity: 0.45 },
  fieldWrap: { gap: 6 },
  label: { color: colors.muted, fontSize: 13, fontWeight: '700' },
  input: {
    backgroundColor: '#f6f8fa',
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    color: colors.text,
    fontSize: 16,
    minHeight: 48,
    paddingHorizontal: 13,
    paddingVertical: 11
  },
  multiline: { minHeight: 120, textAlignVertical: 'top' },
  choiceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  choice: {
    borderColor: colors.border,
    borderRadius: 999,
    borderWidth: 1,
    minHeight: 42,
    justifyContent: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    backgroundColor: colors.surface
  },
  choiceActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  choiceText: { color: colors.text, fontWeight: '700', fontSize: 13 },
  choiceTextActive: { color: '#ffffff' },
  empty: { color: colors.muted, lineHeight: 21, textAlign: 'center', paddingVertical: 30 },
  muted: { color: colors.muted, lineHeight: 20 }
});
