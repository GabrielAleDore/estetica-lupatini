import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/contas_pagar/presentation/cubit/contas_pagar_cubit.dart';
import 'features/contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import 'features/vendas/presentation/cubit/vendas_historico_cubit.dart';
import 'features/vendas/presentation/cubit/vendas_cubit.dart';
import 'features/shell/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';
  await SupabaseService.initialize();
  runApp(const EsteticaLupatiniApp());
}

class EsteticaLupatiniApp extends StatelessWidget {
  const EsteticaLupatiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit()..verificarSessaoInicial(),
        ),
        BlocProvider<VendasCubit>(
          create: (_) => VendasCubit()..carregarDadosIniciais(),
        ),
        BlocProvider<VendasHistoricoCubit>(
          create: (_) => VendasHistoricoCubit(),
        ),
        BlocProvider<ContasPagarCubit>(
          create: (_) => ContasPagarCubit(),
        ),
        BlocProvider<ContasBancariasCubit>(
          create: (_) => ContasBancariasCubit()..carregarContas(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: const MainNavigationShell(),
      ),
    );
  }
}
