import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/either.dart';
import '../repositories/income_repository.dart';

class CreateIncome implements UseCase<void, CreateIncomeParams> {
  final IncomeRepository repository;

  CreateIncome(this.repository);

  @override
  Future<Either<Failure, void>> call(CreateIncomeParams params) {
    return repository.createIncome(
      token: params.token,
      docno: params.docno,
      docdate: params.docdate,
      amount: params.amount,
      detail: params.detail,
      remark: params.remark,
      bankReference: params.bankReference,
      partyName: params.partyName,
      refParty: params.refParty,
      refUser: params.refUser,
      refMoneyType: params.refMoneyType,
      refIncomeType: params.refIncomeType,
      refBudgetSource: params.refBudgetSource,
      subData: params.subData,
      refBankAccount: params.refBankAccount,
      receiptBookId: params.receiptBookId,
      receiptNo: params.receiptNo,
      bumpBudgetSourceBudgetAmount: params.bumpBudgetSourceBudgetAmount,
      docStatus: params.docStatus,
    );
  }
}

class CreateIncomeParams {
  final String token;
  final String docno;
  final String docdate;
  final String amount;
  final String detail;
  final String remark;
  final String? bankReference;
  final String partyName;
  final String? refParty;
  final String refUser;
  final String refMoneyType;
  final String refIncomeType;
  final String? refBudgetSource;
  final List<Map<String, dynamic>> subData;
  final String? refBankAccount;
  final String? receiptBookId;
  final String? receiptNo;
  final bool bumpBudgetSourceBudgetAmount;
  final String docStatus;

  const CreateIncomeParams({
    required this.token,
    required this.docno,
    required this.docdate,
    required this.amount,
    required this.detail,
    required this.remark,
    this.bankReference,
    required this.partyName,
    this.refParty,
    required this.refUser,
    required this.refMoneyType,
    required this.refIncomeType,
    required this.refBudgetSource,
    required this.subData,
    this.refBankAccount,
    this.receiptBookId,
    this.receiptNo,
    this.bumpBudgetSourceBudgetAmount = true,
    this.docStatus = 'posted',
  });
}
