import 'package:flutter/material.dart';

class AppTheme {
  // DUOZZ Brand Colors
  static const Color primaryColor = Color(0xFFE8490E); // DUOZZ Orange
  static const Color primaryDark = Color(0xFFC43A08); // Darker orange for pressed states
  static const Color secondaryColor = Color(0xFF6B6560); // Warm gray from portfolio
  static const Color surfaceColor = Color(0xFFF5F0E8); // Off-white/cream
  static const Color cardColor = Colors.white;
  static const Color scaffoldBg = Color(0xFFFAF8F5); // Light warm background
  static const Color textPrimary = Color(0xFF1A1A1A); // Near black
  static const Color textSecondary = Color(0xFF6B6560); // Warm gray
  static const Color textTertiary = Color(0xFF9E9892); // Lighter warm gray
  static const Color dividerColor = Color(0xFFE8E2D9); // Warm divider
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF2563EB);

  // Status Colors
  static const Color statusDraft = Color(0xFF9E9892);
  static const Color statusInProgress = Color(0xFF2563EB); // Blue - active
  static const Color statusReview = Color(0xFFF59E0B);
  static const Color statusDelivered = Color(0xFF6B6560);
  static const Color statusCompleted = Color(0xFF16A34A);
  static const Color statusArchived = Color(0xFF9E9892);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusApproved = Color(0xFF16A34A);
  static const Color statusRejected = Color(0xFFDC2626);

  // Priority Colors
  static const Color priorityLow = Color(0xFF16A34A);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityHigh = Color(0xFFE8490E);
  static const Color priorityUrgent = Color(0xFFDC2626);

  // Gradient - DUOZZ style (dark charcoal, elegant)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D2926), Color(0xFF1A1A1A)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A1A), Color(0xFF2D2926)],
  );

  // Light Theme ONLY (no dark mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: scaffoldBg,
        error: errorColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: textPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: textTertiary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: textPrimary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor.withOpacity(0.1),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: dividerColor),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: textPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: textPrimary,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Status color helper
  static Color getProjectStatusColor(String status) {
    switch (status) {
      case 'draft':
        return statusDraft;
      case 'in_progress':
        return statusInProgress;
      case 'review':
        return statusReview;
      case 'delivered':
        return statusDelivered;
      case 'completed':
        return statusCompleted;
      case 'archived':
        return statusArchived;
      default:
        return statusDraft;
    }
  }

  static String getProjectStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Rascunho';
      case 'in_progress':
        return 'Em Progresso';
      case 'review':
        return 'Em Revisão';
      case 'delivered':
        return 'Entregue';
      case 'completed':
        return 'Concluído';
      case 'archived':
        return 'Arquivado';
      default:
        return status;
    }
  }

  static Color getTaskStatusColor(String status) {
    switch (status) {
      case 'todo':
        return statusDraft;
      case 'in_progress':
        return statusInProgress;
      case 'review':
        return statusReview;
      case 'done':
        return statusCompleted;
      default:
        return statusDraft;
    }
  }

  static String getTaskStatusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'A Fazer';
      case 'in_progress':
        return 'Em Progresso';
      case 'review':
        return 'Revisão';
      case 'done':
        return 'Concluído';
      default:
        return status;
    }
  }

  static Color getDeliveryStatusColor(String status) {
    switch (status) {
      case 'pending':
        return statusPending;
      case 'uploaded':
        return statusInProgress;
      case 'in_review':
        return statusReview;
      case 'approved':
        return statusApproved;
      case 'rejected':
        return statusRejected;
      case 'revision_requested':
        return warningColor;
      default:
        return statusDraft;
    }
  }

  static String getDeliveryStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'uploaded':
        return 'Enviado';
      case 'in_review':
        return 'Em Revisão';
      case 'approved':
        return 'Aprovado';
      case 'rejected':
        return 'Rejeitado';
      case 'revision_requested':
        return 'Revisão Solicitada';
      default:
        return status;
    }
  }

  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return priorityLow;
      case 'medium':
        return priorityMedium;
      case 'high':
        return priorityHigh;
      case 'urgent':
        return priorityUrgent;
      default:
        return priorityMedium;
    }
  }

  static String getPriorityLabel(String priority) {
    switch (priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return priority;
    }
  }

  static String getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'manager':
        return 'Gerente';
      case 'editor':
        return 'Editor';
      case 'freelancer':
        return 'Freelancer';
      case 'client':
        return 'Cliente';
      default:
        return role;
    }
  }

  static Color getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFE8490E); // DUOZZ Orange for admin
      case 'manager':
        return const Color(0xFF6B6560); // Warm gray
      case 'editor':
        return const Color(0xFF2563EB); // Blue
      case 'freelancer':
        return const Color(0xFFF59E0B); // Amber
      case 'client':
        return const Color(0xFF16A34A); // Green
      default:
        return textSecondary;
    }
  }
}
