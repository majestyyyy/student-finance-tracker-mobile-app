import 'package:postgres/postgres.dart';
import 'package:tracker_api/finance/finance_repository.dart';

Future<void> main() async {
  final connection = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'tracker_azure_test',
      username: 'tracker',
      password: 'tracker_dev_password',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  const userId = 'O8TxcYfOH3Eu6l-5IbtSSBgAmYk9rQiE9VtKumEKq5s';

  await connection.execute(
    Sql.named(
      'INSERT INTO users (id, email, display_name) VALUES (@id, @email, @name)',
    ),
    parameters: {
      'id': userId,
      'email': 'probe@test.com',
      'name': 'Probe',
    },
  );

  final repo = FinanceRepository(connection);
  final resolved = await repo.resolveUserId(userId);
  print('resolveUserId: $resolved');

  final dashboard = await repo.fetchDashboard(userId);
  print('dashboard accounts: ${dashboard['accounts']}');

  final accountId = await repo.insertAccount(
    userId: userId,
    name: 'Test Cash',
    accountType: 'cash',
    typeLabel: 'Cash',
    typeGroup: 'asset',
    balance: 100,
  );
  print('insertAccount id: $accountId');

  final dashboard2 = await repo.fetchDashboard(userId);
  print('dashboard after insert: ${dashboard2['summary']}');

  await connection.close();
}
