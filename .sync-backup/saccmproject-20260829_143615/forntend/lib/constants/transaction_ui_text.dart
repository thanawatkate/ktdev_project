class TransactionUiText {
  const TransactionUiText._();

  static const addItem = 'เพิ่มรายการ';
  static const edit = 'แก้ไข';
  static const cancel = 'ยกเลิก';
  static const ok = 'ตกลง';
  static const save = 'บันทึก';
  static const close = 'ปิด';
  static const lookupPickerOpenTooltip = 'เปิดรายการ';
  static const lookupPickerClearTooltip = 'ล้างการเลือก';
  static const lookupPickerSearchHint = 'ค้นหารายการ...';
  static const lookupPickerLoading = 'กำลังโหลดรายการ...';
  static const lookupPickerNoResults = 'ไม่พบรายการที่ตรงกับคำค้นหา';

  static const summaryIncome = 'สรุปข้อมูลรายรับ';
  static const summaryExpense = 'สรุปข้อมูลรายจ่าย';
  static const summaryLoan = 'สรุปข้อมูลยืมเงิน';
  static const incomeItemInfo = 'ข้อมูลรายการรับเงิน';
  static const expenseItemInfo = 'ข้อมูลรายการเบิกเงิน';
  static const addLoanItem = 'เพิ่มรายการยืมเงิน';
  static const editLoanItem = 'แก้ไขรายการยืมเงิน';
  static const saveEdit = 'บันทึกการแก้ไข';
  static const delete = 'ลบ';
  static const deleteLoanItem = 'ลบรายการยืมเงิน';
  static const confirmDeleteLoan = 'ต้องการลบรายการ';
  static const confirmDeleteQuestion = 'ใช่หรือไม่';
  static const deleteItem = 'ลบรายการ';
  static const loanBorrower = 'ผู้ยืม';
  static const loanBorrowerHint = 'แตะเพื่อเลือกจากทะเบียนสมาชิก';
  static const fillBorrower = 'กรุณาเลือกผู้ยืมจากทะเบียนสมาชิก';
  static const emptyLoan = 'ยังไม่มีข้อมูลยืมเงิน';
  static const loanSearchHint = 'ค้นหาผู้ยืม หรือหมายเหตุ...';
  static const loanOpeningOutstanding = 'ยอดคงค้างยืมยกมา (บาท)';
  static const loanDueDate = 'กำหนดส่งใช้';
  static const loanDueDateHelper = 'กำหนดวันครบกำหนดการส่งใช้เงินยืม';
  static const loanDueDateMustNotBeforeLoanDate =
      'กำหนดส่งใช้ต้องไม่ก่อนวันที่ยืม';
  static const loanOpeningOutstandingHint =
      'หนี้คงค้างก่อนเริ่มบันทึกในระบบ (บวกกับยอดตามเอกสารด้านบนเมื่อคำนวณยอดคงเหลือ)';
  static const loanPrincipalDocAmount = 'ยอดตามเอกสารใบยืม (บาท)';

  /// แสดงใต้ยอดรวมในรายการยืมเมื่อมียอดยกมา (ส่งค่าที่จัดรูปแล้ว)
  static String loanAmountDocPlusBrought(String docAmt, String broughtAmt) =>
      'เอกสาร $docAmt + ยกมา $broughtAmt';
  static const cannotDelete = 'ไม่สามารถลบข้อมูลได้';
  static const addIncomeItem = 'เพิ่มรายการรับเงิน';
  static const editIncomeItem = 'แก้ไขรายการรับเงิน';
  static const addExpenseItem = 'เพิ่มรายการเบิกเงิน';
  static const editExpenseItem = 'แก้ไขรายการเบิกเงิน';
  static const summaryTotal = 'ยอดรวมทั้งหมด';
  static const totalAmount = 'ยอดรวม';
  static const itemCount = 'จำนวนรายการ';
  static const baht = 'บาท';
  static const items = 'รายการ';
  static const notePrefix = 'หมายเหตุ: ';
  static const synced = 'ส่งเซิร์ฟเวอร์แล้ว';
  static const pendingSync = 'รอส่งเซิร์ฟเวอร์';
  static const expenseSyncServerUnavailable =
      'เครื่อง: แสดงรายการจากข้อมูลในเครื่อง — เซิร์ฟเวอร์: ดึงรายการล่าสุดไม่สำเร็จ';

  static const searchHint = 'ค้นหาเลขที่เอกสาร หรือรายละเอียด...';
  static const notFound = 'ไม่พบข้อมูลที่ค้นหา';
  static const emptyIncome = 'ยังไม่มีข้อมูลรายรับ';
  static const emptyExpense = 'ยังไม่มีข้อมูลรายจ่าย';
  static const tryAnotherKeyword = 'ลองใช้คำค้นหาอื่น';
  static const startByAdding = 'แตะ "เพิ่มรายการ" เพื่อเริ่มบันทึก';

  static const loadFailedTitle = 'ไม่สามารถโหลดข้อมูลได้';
  static const saveFailedTitle = 'ไม่สามารถบันทึกข้อมูลได้';
  static const tryAgain = 'ลองอีกครั้ง';
  static const reviewBeforeSave = 'ตรวจสอบข้อมูลก่อนกดบันทึก';

  /// Form UX copy (income / loan) — ใช้ร่วมในหน้าบันทึกรายการ
  static const requiredBeforeSaveHint =
      'กรอกช่องที่มี * ให้ครบก่อนบันทึก: รับจาก, วิธีรับเงิน, หมวดรายรับ, แหล่งเงิน และจำนวนเงิน';
  static const incomePageGuideTitle = 'คู่มือบันทึกรับเงิน';
  static const incomeQuickGuideHint =
      'ลำดับแนะนำ: เลือกหมวดรายรับ → แหล่งเงิน (เฉพาะที่ผูกกับหมวด) → วิธีรับและจำนวนเงิน — ตรวจสรุปด้านล่างก่อนบันทึก';
  static const incomeAccountingStep1Label =
      'หมวดรายรับ โดเมนการเงิน และแหล่งเงิน';
  static const incomeAccountingStep2Label = 'วิธีรับเงินและจำนวนเงิน';
  static const incomeBankReferenceLabel = 'หลักฐานอ้างอิงธนาคาร';
  static const incomeBankReferenceHint =
      'เช่น เลขรายการใน statement หรือดอกเบี้ยงวด 01/2567';
  static const incomeBankReferenceHelper =
      'ใช้ตรวจสอบย้อนหลังเมื่อรับผ่านธนาคาร โดยเฉพาะดอกเบี้ยบัญชีหรือเงินโอน';
  static const incomeBankReferenceSectionHint =
      'รายการนี้เกี่ยวข้องกับธนาคาร จึงสามารถระบุเลขอ้างอิงจากสมุดบัญชีหรือ statement ได้';
  static const incomeMoneyDomainLabel = 'โดเมนการเงิน';
  static const incomeMoneyDomainHelper =
      'จำแนกอัตโนมัติจากหมวดรายรับที่เลือก (เก็บในฐานข้อมูลเป็น money_domain)';
  static const incomeMoneyDomainBudget = 'งบประมาณ';
  static const incomeMoneyDomainOffBudget = 'นอกงบประมาณ';
  static const incomeMoneyDomainTreasury = 'รายได้แผ่นดิน';
  static const incomeMoneyDomainOther = 'นอกงบประมาณ (อื่น ๆ)';

  /// ค่า canonical ตาม backend / SQLite — ใช้แสดงผลเท่านั้น
  static String incomeMoneyDomainThai(String? code) {
    switch ((code ?? '').trim().toLowerCase()) {
      case 'budget':
        return incomeMoneyDomainBudget;
      case 'off_budget':
        return incomeMoneyDomainOffBudget;
      case 'treasury_income':
        return incomeMoneyDomainTreasury;
      default:
        return incomeMoneyDomainOther;
    }
  }

  static const incomeBudgetFilteredByCategoryBanner =
      'แสดงเฉพาะแหล่งเงินที่ผูกกับหมวดรายรับที่เลือก';
  static const incomeTypeHelperText = 'เลือกหมวดให้ตรงทะเบียนรับ-จ่ายและรายงาน';
  static const incomeNoBudgetInCategoryHint = 'ยังไม่มีแหล่งเงินในหมวดรับนี้';
  static const incomeNoBudgetInCategoryHelper =
      'หมวดรับที่เลือกยังไม่ผูกแหล่งเงิน จึงยังเลือกแหล่งเงินไม่ได้';
  static const incomeDepositRegisterTypeNotAllowed =
      'เงินประกันสัญญา/ภาษีหัก ณ ที่จ่าย ต้องบันทึกผ่านเมนูทะเบียนคุม';
  static const incomeChooseCategoryFirstHint = 'กรุณาเลือกหมวดรับก่อน';
  static const incomeBudgetSourceSelectLockedHelper =
      'ยังไม่สามารถเลือกแหล่งเงินได้จนกว่าจะเลือกหมวดรับ';
  static const incomeBudgetSourceWhenCategoryOkHelper =
      'เลือกแหล่งที่มาของรายรับ';
  static const incomeGoFixBudgetInIncomeTypePage =
      'ไปผูกแหล่งเงินในหน้าหมวดรายรับ';
  static String incomeGoFixBudgetInIncomeTypePageNamed(String categoryName) =>
      'ไปผูกแหล่งเงินในหมวดรับ: $categoryName';
  static const incomeReadyToSave = 'พร้อมบันทึกรายการแล้ว';
  static const incomeMissingRequiredPrefix = 'กรุณากรอก: ';
  static const incomeMissingFieldCategory = 'หมวดรายรับ';
  static const incomeMissingFieldBudget = 'แหล่งเงิน';
  static const incomeMissingFieldReceiveFrom = 'รับจาก';
  static const incomeMissingFieldAmount = 'จำนวนเงิน';
  static const incomeDocNoCreateFailed =
      'ไม่สามารถสร้างเลขที่เอกสารได้ กรุณาลองใหม่';
  static const incomeSpecifyReceiveFrom = 'กรุณาระบุรับจาก';
  static const incomeBudgetEmptyDialogTitle = 'ยังไม่มีแหล่งงบในหมวดรายรับ';
  static const incomeBudgetEmptyDialogBody =
      'หมวดรายรับที่เลือกยังไม่ผูกแหล่งเงิน ต้องการไปหน้า "หมวดรายรับ" เพื่อแก้ไขตอนนี้หรือไม่?';
  static const incomeBudgetEmptyDialogConfirm = 'ไปแก้ไข';

  /// บรรทัดแรกของฟิลด์รายละเอียดแบบเก่าที่แยกชื่อผู้จ่ายออกจากเนื้อหา
  static const incomeSavedDetailReceiveFromPrefix = 'รับจาก:';
  static const incomePreviewTitle = 'สรุปก่อนบันทึก';
  static const incomePreviewIncomplete =
      'กรอกข้อมูลสำคัญให้ครบ แล้วระบบจะแสดงสรุปรายการที่นี่';
  static const incomePreviewPayer = 'รับจาก';
  static const incomePreviewMethod = 'วิธีรับ';
  static const incomePreviewType = 'หมวด';
  static const incomePreviewBudget = 'แหล่งงบ';
  static const incomePreviewAmount = 'จำนวนเงิน';
  static const notSelected = 'ยังไม่เลือก';
  static const budgetSourceEmptyHint =
      'ยังไม่มีแหล่งงบที่ใช้งานได้สำหรับหมวดรายรับนี้';
  static const budgetSourceEmptyHelper =
      'ไปเพิ่มหรือผูกแหล่งงบให้หมวดรายรับนี้ก่อน แล้วกลับมาเลือกอีกครั้ง';
  static const goManageBudgetSource = 'ไปจัดการแหล่งงบ';
  static const budgetSourceRefreshedReady =
      'รีเฟรชแหล่งงบแล้ว สามารถเลือกแหล่งงบได้';
  static const budgetSourceRefreshedStillEmpty =
      'รีเฟรชแหล่งงบแล้ว แต่ยังไม่มีรายการสำหรับหมวดนี้';
  static const incomeUnsavedLeaveTitle = 'ออกจากหน้านี้?';
  static const incomeUnsavedLeaveBody =
      'มีข้อมูลที่ยังไม่ได้บันทึก ต้องการออกโดยไม่บันทึกหรือไม่';
  static const incomeUnsavedStay = 'อยู่ต่อ';
  static const incomeUnsavedLeaveWithoutSave = 'ออกโดยไม่บันทึก';
  static const formUnsavedLeaveTitle = incomeUnsavedLeaveTitle;
  static const formUnsavedLeaveBody = incomeUnsavedLeaveBody;
  static const formUnsavedStay = incomeUnsavedStay;
  static const formUnsavedLeaveWithoutSave = incomeUnsavedLeaveWithoutSave;
  static const incomeResetTitle = 'ล้างฟอร์ม?';
  static const incomeResetBody = 'ข้อมูลที่กรอกไว้จะถูกล้างทั้งหมด';
  static const incomeResetCancel = 'ยกเลิก';
  static const incomeResetConfirm = 'ล้างข้อมูล';
  static const incomeResetDone = 'ล้างฟอร์มเรียบร้อยแล้ว';
  static const expensePageGuideTitle = 'คู่มือบันทึกรายจ่าย';
  static const expenseQuickGuideTitle = 'ลำดับทำงาน';
  static const expenseQuickGuideStepType = '1. เลือกประเภทรายจ่าย';
  static const expenseQuickGuideStepBudget = '2. เลือกแหล่งเงิน';
  static const expenseQuickGuideStepPayment = '3. ระบุวิธีจ่ายและยอดเงิน';
  static const expenseQuickGuideStepOb =
      '4. เลือกหมวดทะเบียนคุมเมื่อเป็นนอกงบฯ';
  static const expenseQuickGuideHint =
      'ทำตามลำดับจากซ้ายไปขวา ระบบจะใช้ข้อมูลนี้คำนวณทะเบียนคุมและรายงานเงินคงเหลือ';

  /// หัวฟอร์มรายจ่าย — แยกประเภทรายจ่าย(พัสดุ) แหล่งเงิน หมวดทะเบียนคุม(นอกงบฯ) และรูปแบบการจ่าย
  static const expenseRequiredBeforeSaveHint =
      'กรอกช่องที่มี * ให้ครบ: ประเภทรายจ่าย, แหล่งเงิน, รูปแบบการจ่าย, จ่ายให้ และจำนวนเงิน — ถ้าเป็นเงินนอกงบประมาณ ให้เลือกหมวดทะเบียนคุมให้ตรงสมุดรับ-จ่าย';
  static const expenseDocNoCreateFailed =
      'ไม่สามารถสร้างเลขที่เอกสารได้ กรุณาลองใหม่';
  static const expenseAccountingSectionTitle = 'การจ่ายเงิน';
  static const expenseMoneyChannelTitle = 'รูปแบบการจ่าย';
  static const expenseMoneyChannelHelper =
      'เลือกให้ตรงช่องทางจริง (เงินสด / ฝากธนาคาร / ส่วนราชการผู้เบิก) เพื่อใช้ในทะเบียนคุมและรายงานเงินคงเหลือ';
  static const expenseFundCategoryTitle = 'หมวดเงินนอกงบประมาณ (ทะเบียนคุม)';
  static const expenseFundCategoryHelper =
      'เมื่อจ่ายจากเงินนอกงบประมาณ ให้เลือกหมวด OB-01..OB-13 ให้ตรงกับสมุดรับ-จ่าย';
  static const expenseFundCategoryChooseFirst =
      'เลือกแหล่งเงินก่อน แล้วเลือกหมวดทะเบียนคุม';
  static const expenseSelectFundCategory =
      'กรุณาเลือกหมวดเงินนอกงบประมาณ (ทะเบียนคุม)';
  static const expenseSelectMoneyChannel = 'กรุณาเลือกรูปแบบการจ่าย';
  static const expenseNoObCategoriesHint =
      'ยังไม่มีหมวด OB ในระบบ — ตรวจสอบการ seed ข้อมูลหรือซิงก์ข้อมูลมาตรฐาน';
  static const goManageIncomeTypesOb = 'ไปจัดการหมวดรายรับ (OB)';
  static const expenseReadyToSave = 'พร้อมบันทึกรายการแล้ว';
  static const expenseMissingRequiredPrefix = 'กรุณากรอก: ';
  static const formClearTooltip = 'ล้างฟอร์ม';
  static const docNoAutoHelper = 'ระบบคำนวณตามรูปแบบเลขที่เอกสารโดยอัตโนมัติ';
  static const positiveAmountHelper = 'ระบุยอดมากกว่า 0 บาท';
  static const partyPickerTooltip = 'เลือกรายชื่อจากระบบ';
  static const partyPickerClearTooltip = 'ล้างการเลือก';
  static const expenseChooseTypeFirstHint = 'กรุณาเลือกประเภทรายจ่ายก่อน';
  static const expenseNoBudgetSourceForTypeHint = 'ยังไม่มีแหล่งเงินในระบบ';
  static const expenseNoBudgetSourceForTypeHelper =
      'ยังไม่พบข้อมูลแหล่งเงินในเครื่อง จึงยังเลือกแหล่งเงินไม่ได้';
  static const expenseBudgetEmptyDialogTitle = 'ยังไม่มีแหล่งเงินในระบบ';
  static const expenseBudgetEmptyDialogBody =
      'ยังไม่พบข้อมูลแหล่งเงินในเครื่อง ต้องการไปหน้าแหล่งเงินเพื่อเพิ่มรายการตอนนี้หรือไม่?';
  static const expenseBudgetSourceHelper = 'เลือกแหล่งงบที่ใช้จ่ายเงิน';
  static const expenseBudgetSourceFilteredHelper =
      'เลือกแหล่งงบที่ใช้จ่ายเงินจริงในรายการนี้';
  static const expenseBudgetFilterBannerGov =
      'ตรวจสอบให้แหล่งเงินสอดคล้องกับเอกสารและทะเบียนคุมที่ใช้จริง';
  static const expenseBudgetFilterBannerNonGov =
      'ตรวจสอบให้แหล่งเงินสอดคล้องกับเอกสารและทะเบียนคุมที่ใช้จริง';
  static const expenseGoFixBudgetInExpenseTypePage = 'ไปจัดการแหล่งเงิน';
  static String expenseGoFixBudgetInExpenseTypePageNamed(String typeName) =>
      'ไปจัดการแหล่งเงิน';
  static const expenseAccountingStep1Label = 'ประเภทรายจ่ายและแหล่งเงิน';
  static const expenseAccountingStep2Label =
      'ทะเบียนคุม (เมื่อจ่ายจากนอกงบประมาณ)';
  static const expenseAccountingStep3Label = 'ช่องทางการจ่ายและจำนวนเงิน';
  static const expenseEntryFormTitle = 'บันทึกรายจ่าย';
  static const expenseEntryFormSubtitle =
      'เลือกประเภทและแหล่งเงิน ตรวจยอดคงเหลือก่อนยืนยันการจ่าย';
  static const expenseBudgetAvailableLabel = 'ยอดคงเหลือที่ใช้ได้';
  static const expenseAmountExceedsAvailableWarning =
      'จำนวนเงินที่จะจ่ายมากกว่ายอดคงเหลือที่ใช้ได้';
  static const expenseEntryOpenFullVoucherTooltip = 'เปิดใบจ่ายแบบเต็ม';
  static const expenseEntryFabLabel = 'ฟอร์มย่อ';
  static const expenseChequeStepLabel =
      'ข้อมูลเช็ค (เมื่อรูปแบบการจ่ายเป็นเช็ค)';
  static const expenseChequeAccountTitle = 'บัญชีเช็ค (ธนาคาร/สาขา)';
  static const expenseChequeAccountHelper =
      'เลือกบัญชีเช็คที่ใช้สั่งจ่าย เพื่อบันทึกในทะเบียนคุมจ่ายเช็ค';
  static const expenseChequeNoTitle = 'เลขที่เช็ค';
  static const expenseChequeNoHint = 'เช่น 0000123';
  static const expenseChequeNoHelper =
      'ระบุเลขที่เช็คที่ออกในเล่ม (จำเป็นสำหรับทะเบียนคุมจ่ายเช็ค)';
  static const expenseChequeNoAccountHint =
      'ยังไม่มีบัญชีเช็คในระบบ — กรุณาเพิ่มในเมนูบัญชีเช็คก่อนสั่งจ่ายเช็ค';
  static const expenseChequeSelectAccount = 'กรุณาเลือกบัญชีเช็ค';
  static const expenseChequeFillNo = 'กรุณาระบุเลขที่เช็ค';
  static const expenseChequeLineLabel = 'เช็คที่';
  static const expenseChequeAmountLabel = 'จำนวนเงินเช็ค';
  static const expenseChequeAddLine = 'เพิ่มใบเช็ค';
  static const expenseChequeFillRemainder = 'เติมยอดคงเหลือ';
  static const expenseChequeSumMismatch =
      'ผลรวมจำนวนเงินเช็คต้องเท่ากับยอดรายจ่าย';
  static String expenseChequeSumMismatchDetail(double sum, double total) =>
      'รวมเช็ค ${sum.toStringAsFixed(2)} บาท — ยอดรายจ่าย ${total.toStringAsFixed(2)} บาท';
  static const registerChequeStatusLabel = 'สถานะ';
  static const registerChequeStatusOutstanding = 'ค้างตัด';
  static const registerChequeStatusCleared = 'ตัดบัญชีแล้ว';
  static const registerChequeMarkCleared = 'บันทึกตัดบัญชีแล้ว';
  static const registerChequeMarkClearedConfirm =
      'บันทึกว่าเช็คนี้ขึ้นเงิน/ตัดบัญชีแล้ว?';
  static const registerChequeClearedDone = 'บันทึกสถานะตัดบัญชีแล้ว';

  /// ข้อความเตือนวงเงินเก็บรักษา (cash_keeping_limit)
  static String expenseLineAmountLabel(int lineNo) =>
      'จำนวนเงิน (บรรทัด $lineNo)';
  static const expensePrimaryAmountLabel = 'จำนวนเงินที่จ่าย';
  static const expensePrimaryLineTitle = 'ยอดจ่ายหลัก';
  static String expenseSplitLineTitle(int lineNo) => 'รายการแยกยอดที่ $lineNo';
  static const expenseSplitLinesTitle = 'รายการแยกยอดเพิ่มเติม';
  static const expenseAddSubLine = 'เพิ่มรายการแยกยอด';
  static const expenseMultiLineAmountHelper =
      'ถ้าจ่ายครั้งเดียวให้กรอกเฉพาะยอดนี้; ใช้ “เพิ่มรายการแยกยอด” เมื่อใบเดียวต้องแยกหลายหมวด';
  static const expenseLineRemarkLabel = 'หมายเหตุของรายการนี้ (ไม่จำเป็น)';
  static const expenseLineRemarkToggle = 'เพิ่ม/แก้หมายเหตุของรายการนี้';
  static const expenseLineRemarkHint =
      'ใช้เมื่อรายการนี้ต้องการคำอธิบายเพิ่มเติม';
  static const expenseRemoveSubLineTooltip = 'ลบบรรทัดนี้';
  static const expenseEditReasonTitle = 'เหตุผลในการแก้ไขเอกสาร';
  static const expenseEditReasonHint =
      'ระบุเหตุผลที่แก้ไข เพื่อให้ตรวจสอบประวัติการเปลี่ยนแปลงได้';
  static const expenseEditReasonCancel = 'ยกเลิก';
  static const expenseEditReasonConfirm = 'ดำเนินการต่อ';
  static const expenseEditReasonRequired =
      'กรุณาระบุเหตุผลในการแก้ไขก่อนบันทึก';

  /// สถานะเอกสารรายรับ (สอดคล้อง income.doc_status บนเซิร์ฟเวอร์)
  static const incomeDocStatusLabel = 'สถานะเอกสาร';
  static const incomeDocStatusDraft = 'ร่าง';
  static const incomeDocStatusApproved = 'อนุมัติแล้ว';
  static const incomeDocStatusPosted = 'ลงบัญชีแล้ว';

  static String expenseKeepLimitHint({
    required String fundLabel,
    required double cashMax,
    required double bankMax,
  }) {
    String fmt(double v) => v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'วงเงินเก็บรักษา ($fundLabel): เงินสดสูงสุด ${fmt(cashMax)} บาท / ฝากธนาคารสูงสุด ${fmt(bankMax)} บาท — '
        'หากยอดสะสมเกินเพดานต้องนำส่งคลังหรือฝากธนาคารตามระเบียบที่ใช้งาน';
  }

  static const expenseBudgetSourceSelectLockedHelper =
      'ยังไม่สามารถเลือกแหล่งงบได้จนกว่าจะเลือกประเภทรายจ่าย';
  static const expenseUnsavedLeaveTitle = 'ออกจากหน้านี้?';
  static const expenseUnsavedLeaveBody =
      'มีข้อมูลที่ยังไม่ได้บันทึก ต้องการออกโดยไม่บันทึกหรือไม่';
  static const expenseUnsavedStay = 'อยู่ต่อ';
  static const expenseUnsavedLeaveWithoutSave = 'ออกโดยไม่บันทึก';
  static const expenseResetTitle = 'ล้างฟอร์ม?';
  static const expenseResetBody = 'ข้อมูลที่กรอกไว้จะถูกล้างทั้งหมด';
  static const expenseResetCancel = 'ยกเลิก';
  static const expenseResetConfirm = 'ล้างข้อมูล';
  static const expenseResetDone = 'ล้างฟอร์มเรียบร้อยแล้ว';

  static const loanRequiredBeforeSaveHint =
      'กรอกข้อมูลที่จำเป็นให้ครบ: ผู้ยืม วันที่ยืม และยอดเงิน แล้วตรวจสอบรายการก่อนบันทึก';
  static const loanPageGuideTitle = 'คู่มือบันทึกยืมเงิน';
  static const loanQuickGuideHint =
      'เริ่มจากเลือกผู้ยืมและวันที่ จากนั้นเพิ่มรายการย่อยตามหมวดรายรับและจำนวนเงิน ระบบจะรวมยอดให้อัตโนมัติ';
  static const loanDocNoAutoHelper =
      'ระบบคำนวณตามรูปแบบเลขที่เอกสารโดยอัตโนมัติ';
  static const loanPrincipalAmountHelper =
      'ยอดตามเอกสารคำนวณจากรายการย่อยทั้งหมดโดยอัตโนมัติ';
  static const loanBorrowerHelper = 'เลือกผู้ยืมจากทะเบียนสมาชิกของโรงเรียน';
  static const loanBorrowerPickerTitle = 'เลือกผู้ยืม (ทะเบียนสมาชิก)';
  static const loanBorrowerPickerSearchHint = 'ค้นหาชื่อหรือรหัสสมาชิก';
  static const loanBorrowerPickerLoading = 'กำลังโหลดทะเบียนสมาชิก...';
  static const loanBorrowerNoMembersTitle = 'ยังไม่มีสมาชิกในระบบ';
  static const loanBorrowerNoMembersBody =
      'เพิ่มสมาชิกในทะเบียนก่อนจึงจะบันทึกใบยืมได้ — ต้องการไปหน้าทะเบียนสมาชิกหรือไม่?';
  static const loanBorrowerGoRegister = 'ไปทะเบียนสมาชิก';
  static const loanBorrowerClearTooltip = 'ล้างการเลือกผู้ยืม';
  static String loanHasOutstandingBlock(String docno, String amount) =>
      'ผู้ยืมรายนี้มีหนี้ค้างจากใบยืม $docno (คงเหลือ $amount บาท) ยังไม่สามารถยืมใหม่ได้';
  static const loanOverdueBadge = 'เกินกำหนด';
  static const loanDueSoonBadge = 'ใกล้ครบกำหนด';
  static const loanOutstandingBadge = 'ค้างชำระ';
  static const loanDuePrefix = 'ครบกำหนด';
  static const repayLoanSummaryPrefix = 'ยอดคืนเงินยืมรวม';
  static const repayLoanSearchHint =
      'ค้นหาเลขที่คืน/อ้างอิงใบยืม/หมายเหตุ/จำนวนเงิน';
  static const repayLoanEmpty = 'ยังไม่มีข้อมูลคืนเงินยืม';
  static const addRepayLoan = 'เพิ่มคืนเงินยืม';
  static const loanReadyToSave = 'พร้อมบันทึกรายการแล้ว';
  static const loanMissingRequiredPrefix = 'กรุณากรอก: ';
  static const loanMissingAmountEither = 'จำนวนเงิน (ยอดเอกสารหรือยอดยกมา)';
  static const loanUnsavedLeaveTitle = 'ออกจากหน้านี้?';
  static const loanUnsavedLeaveBody =
      'มีข้อมูลที่ยังไม่ได้บันทึก ต้องการออกโดยไม่บันทึกหรือไม่';
  static const loanUnsavedStay = 'อยู่ต่อ';
  static const loanUnsavedLeaveWithoutSave = 'ออกโดยไม่บันทึก';
  static const loanResetTitle = 'ล้างฟอร์ม?';
  static const loanResetBody = 'ข้อมูลที่กรอกไว้จะถูกล้างทั้งหมด';
  static const loanResetCancel = 'ยกเลิก';
  static const loanResetConfirm = 'ล้างข้อมูล';
  static const loanResetDone = 'ล้างฟอร์มเรียบร้อยแล้ว';

  /// ชีตเลือกหมวดรายรับสำหรับแถว loan_sub
  static const loanSubPickerTitle = 'เลือกหมวดรายรับ';
  static const loanSubPickerSearchHint = 'ค้นหาชื่อหรือรหัสหมวด';
  static const loanSubPickerLoading = 'กำลังโหลดหมวดรายรับ...';
  static const loanSubPickerEmpty =
      'ไม่มีหมวดรายรับในระบบ — ตั้งค่าหมวดรายรับก่อน';

  static const loanSchemaSectionLoanTitle = 'ข้อมูลเอกสารยืมเงิน';
  static const loanSchemaSectionLoanSubtitle =
      'เลขที่เอกสาร วันที่ยืม กำหนดส่งใช้ ผู้ยืม ยอดคงค้างยกมา และหมายเหตุ';
  static const loanSchemaSectionLoanSubTitle = 'รายการย่อยเงินยืม';
  static const loanSchemaSectionLoanSubSubtitle =
      'ระบุหมวดรายรับ จำนวนเงิน และหมายเหตุของแต่ละรายการ';
  static const loanSubPickCategory = 'หมวดรายรับ';
  static const loanSubPickCategoryHint = 'แตะเพื่อเลือกหมวดรายรับ';
  static const loanSubAmount = 'จำนวนเงิน';
  static const loanSubRemark = 'หมายเหตุ';
  static String loanSubRowTitle(int rowNo) => 'รายการย่อยที่ $rowNo';
  static const loanSubAdditionalRowsTitle = 'รายการย่อยเพิ่มเติม';
  static const loanSubAddRow = 'เพิ่มแถว';
  static const loanSubRemoveRow = 'ลบแถว';
  static const loanSubNeedCategory = 'ทุกแถวที่มียอดต้องเลือกหมวดรายรับ';
  static const loanSubNeedPrincipalOrOpening =
      'ต้องมียอดตามเอกสาร (ผลรวม loan_sub) หรือ opening_outstanding อย่างน้อยหนึ่งค่า';

  static const repayLoanAddItem = 'เพิ่มรายการคืนเงินยืม';
  static const repayLoanEditItem = 'แก้ไขรายการคืนเงินยืม';
  static const repayLoanRequiredBeforeSaveHint =
      'กรอกเลขที่อ้างอิงใบยืมและจำนวนเงินที่คืนให้ครบก่อนบันทึก';
  static const repayLoanPageGuideTitle = 'คู่มือบันทึกคืนเงินยืม';
  static const repayLoanQuickGuideHint =
      'เลือกเลขที่ใบยืมจากรายการในฐานข้อมูล ตรวจยอดคงเหลือด้านล่าง แล้วระบุยอดคืนไม่เกินคงเหลือ';
  static const repayLoanRefLoanLabel = 'อ้างอิงเลขที่ใบยืม';
  static const repayLoanRefLoanHint = 'แตะเพื่อเลือกจากรายการใบยืม';
  static const repayLoanRefLoanHelperPick =
      'แตะช่องด้านบนเพื่อเปิดรายการใบยืมจากฐานข้อมูล (ค้นหาและกรองได้) หรือกดไอคอนล้างเพื่อเปลี่ยนรายการ';
  static const repayLoanClearRefTooltip = 'ล้างการเลือกใบยืม';
  static const repayLoanPickerTitle = 'เลือกเลขที่ใบยืม';
  static const repayLoanPickerSearchHint = 'ค้นหาเลขที่เอกสารหรือชื่อผู้ยืม';
  static const repayLoanPickerFilterLabel = 'กรองรายการ';
  static const repayLoanPickerSortLabel = 'เรียงลำดับ';
  static const repayLoanPickerSortDueDateAsc = 'วันครบกำหนด (เร็วสุดก่อน)';
  static const repayLoanPickerSortRemainingDesc = 'ยอดคงเหลือ (มากสุดก่อน)';
  static const repayLoanFilterAll = 'ทั้งหมด';
  static const repayLoanFilterOutstandingOnly = 'ค้างชำระ';
  static const repayLoanFilterDueSoon7Days = 'ครบกำหนดใน 7 วัน';
  static const repayLoanFilterOverdueOnly = 'เกินกำหนด';
  static const repayLoanPickerEmpty =
      'ไม่มีรายการตามคำค้นหาหรือตัวกรอง — ลองเปลี่ยนเงื่อนไข';
  static const repayLoanPickerNoLoansInDb =
      'ยังไม่มีใบยืมในระบบ — บันทึกใบยืมก่อน แล้วค่อยบันทึกรายการคืนเงิน';
  static String repayLoanSuggestionSubtitle(String borrower, String remain) =>
      'ผู้ยืม: $borrower • คงเหลือ: $remain ${TransactionUiText.baht}';
  static String repayLoanPickerRowSubtitle({
    required String borrower,
    required String dueDisplay,
    required String remaining,
  }) =>
      'ผู้ยืม: $borrower • $loanDueDate: $dueDisplay • คงเหลือ: $remaining ${TransactionUiText.baht}';
  static const repayLoanSnackFillRef = 'กรุณาเลือกเลขที่ใบยืมจากรายการ';
  static const repayLoanSnackLoanNotFound =
      'ไม่พบเลขที่ใบยืมในระบบ กรุณาเลือกจากรายการอีกครั้ง';
  static const repayLoanSnackFullyRepaid = 'ใบยืมนี้คืนครบแล้ว';
  static String repayLoanSnackExceedsRemaining(String remainWithUnit) =>
      'ยอดคืนเกินคงเหลือ ($remainWithUnit)';
  static String repayLoanRemainingHint({
    required String borrower,
    required String dueDate,
    required String remaining,
  }) =>
      'ผู้ยืม: $borrower • ครบกำหนด: $dueDate • คงเหลือ: $remaining บาท';
  static String repayLoanOverdueHint({
    required String borrower,
    required String dueDate,
    required String remaining,
  }) =>
      'รายการนี้เกินกำหนดส่งใช้แล้ว (ครบกำหนด $dueDate) — ผู้ยืม: $borrower • คงเหลือ: $remaining บาท';

  static const providerNotFound =
      'ไม่พบข้อมูลหน้าปัจจุบัน กรุณาเปิดหน้าใหม่อีกครั้ง';
  static const success = 'สำเร็จ';
  static const error = 'ข้อผิดพลาด';
  static const warning = 'แจ้งเตือน';
  static const noData = 'ไม่มีข้อมูล';

  static const documentInfo = 'ข้อมูลเอกสาร';
  static const date = 'วันที่';
  static const docNumber = 'เลขที่เอกสาร';
  static const autoGenerated = 'ระบบสร้างอัตโนมัติ';
  static const additionalDetails = 'รายละเอียดเพิ่มเติม';
  static const detail = 'รายละเอียด';
  static const receiveFrom = 'รับจาก';
  static const receiveFromHint = 'แตะเพื่อเลือกผู้จ่ายที่ลงทะเบียน (ใช้งาน)';
  static const receiveFromHelperRegisteredOnly =
      'เลือกได้เฉพาะผู้จ่ายหรือ “ทั้งสองฝั่ง” ที่ลงทะเบียน — เมนูตั้งค่า → ผู้รับ/ผู้จ่าย';
  static const receiveFromQuickPickLabel = 'เลือกจากรายชื่อผู้จ่าย';
  static const receiveFromQuickPickHint =
      'แตะปุ่มนี้เพื่อเลือกรายชื่อผู้จ่ายจากระบบได้ทันที';
  static const receiveFromMustBeRegistered =
      'กรุณาเลือก "รับจาก" จากรายชื่อผู้จ่ายที่ลงทะเบียนในระบบ';
  static const receiveFromNoPayerDialogTitle = 'ยังไม่มีผู้จ่ายที่ใช้งาน';
  static const receiveFromNoPayerDialogBody =
      'เพิ่มหรือเปิดใช้งานผู้จ่าย (หรือบทบาท “ทั้งสองฝั่ง”) ได้ที่ เมนู “ตั้งค่าระบบ” → “ผู้รับ/ผู้จ่าย” จากนั้นกลับมาแตะ “รับจาก” เพื่อเลือกรายชื่ออีกครั้ง';
  static const receiveFromGoAddParty = 'ไปจัดการผู้รับ/ผู้จ่าย';
  static const incomePayerPickerTitle = 'เลือกผู้จ่าย';
  static const incomePayerPickerSearchHint = 'ค้นหาชื่อผู้จ่าย';
  static const incomePayerPickerLoading = 'กำลังโหลดรายชื่อผู้จ่าย…';
  static const incomePayerRoleBoth = 'ทั้งสองฝั่ง (จ่ายได้)';
  static const incomePayerRolePayer = 'ผู้จ่าย';

  /// รายจ่าย — จ่ายให้ (ผู้รับเงิน)
  static const payTo = 'จ่ายให้';
  static const payToHint = 'แตะเพื่อเลือกผู้รับที่ลงทะเบียน (ใช้งาน)';
  static const payToHelperRegisteredOnly =
      'เลือกได้เฉพาะผู้รับหรือ “ทั้งสองฝั่ง” ที่ลงทะเบียน — เมนูตั้งค่า → ผู้รับ/ผู้จ่าย';
  static const payToMustBeRegistered =
      'กรุณาเลือก "จ่ายให้" จากรายชื่อผู้รับที่ลงทะเบียนในระบบ';
  static const payToRequired = 'กรุณาเลือกจ่ายให้';
  static const payToNoReceiverDialogTitle = 'ยังไม่มีผู้รับที่ใช้งาน';
  static const payToNoReceiverDialogBody =
      'เพิ่มหรือเปิดใช้งานผู้รับ (หรือบทบาท “ทั้งสองฝั่ง”) ได้ที่ เมนู “ตั้งค่าระบบ” → “ผู้รับ/ผู้จ่าย” จากนั้นกลับมาแตะ “จ่ายให้” เพื่อเลือกรายชื่ออีกครั้ง';
  static const expensePayeePickerTitle = 'เลือกผู้รับเงิน';
  static const expensePayeePickerSearchHint = 'ค้นหาชื่อผู้รับเงิน';
  static const expensePayeePickerLoading = 'กำลังโหลดรายชื่อผู้รับเงิน…';
  static const expensePayeeRoleBoth = 'ทั้งสองฝั่ง (รับได้)';
  static const expensePayeeRolePayee = 'ผู้รับ';
  static const payToStaleEditCleared =
      'ชื่อจ่ายให้เดิมไม่อยู่ในรายชื่อที่ใช้งาน กรุณาเลือกใหม่จากรายการ';

  static const receiveFromStaleEditCleared =
      'ชื่อรับจากเดิมไม่อยู่ในรายชื่อที่ใช้งาน กรุณาเลือกใหม่จากรายการ';
  static const remark = 'หมายเหตุ';
  static const remarkHint = 'ระบุหมายเหตุเพิ่มเติม (ถ้ามี)';
  static const amount = 'จำนวนเงิน';
  static const amountTypeSection = 'ประเภทและยอดเงิน';
  static const payerAmountSection = 'ผู้จ่ายและยอดเงิน';
  static const categoryBudgetSection = 'ประเภทและแหล่งงบ';
  static const detailsOnlySection = 'รายละเอียด';
  static const amountSection = 'ยอดเงิน';
  static const incomeType = 'หมวดรายรับ';
  static const receiveMethod = 'วิธีรับเงิน';
  static const incomeDetailHint = 'ระบุรายละเอียดรายการรับเงิน';
  static const incomeDetailExampleHint =
      'เช่น รับเงินสนับสนุนกิจกรรม / รับเงินบริจาค / รับคืนเงิน';
  static const incomeDetailHelper =
      'อธิบายที่มาของรายรับแบบสั้นๆ เพื่อให้ค้นหาและตรวจสอบย้อนหลังได้ง่าย';
  static const expenseDetailHint = 'ระบุรายละเอียดรายการเบิกเงิน';
  static const expenseDetailRequiredHelper =
      'ใบสำคัญคู่จ่ายต้องมีรายละเอียดประกอบ กรุณาเขียนวัตถุประสงค์ให้ตรวจสอบย้อนหลังได้';
  static const expenseDetailRequiredError =
      'กรุณาระบุรายละเอียดรายการเบิกเงิน (จำเป็นตามใบสำคัญคู่จ่าย)';

  static const saveSuccessTitle = 'ดำเนินการสำเร็จ';
  static const saveIncomeSuccess = 'บันทึกรายการรับเงินเรียบร้อยแล้ว';
  static const updateIncomeSuccess = 'แก้ไขรายการรับเงินเรียบร้อยแล้ว';
  static const saveExpenseSuccess = 'บันทึกรายการเบิกเงินเรียบร้อยแล้ว';
  static const updateExpenseSuccess = 'แก้ไขรายการเบิกเงินเรียบร้อยแล้ว';

  static const fillAmount = 'กรอกจำนวนเงิน';
  static const amountMustPositive = 'จำนวนเงินต้องมากกว่า 0 บาท';
  static const selectReceiveMethod = 'เลือกวิธีรับเงิน';
  static const selectIncomeType = 'เลือกหมวดรายรับ';
  static const incomeEntryIssueReceipt = 'ออกใบเสร็จรับเงิน';
  static const incomeReceiptBookLabel = 'เล่มที่ใบเสร็จ';
  static const incomeReceiptNoLabel = 'เลขที่ใบเสร็จ';

  /// [nextFormatted] เลขถัดไปที่คาดหวัง (ตัวเลขหรือข้อความตามที่ผู้ใช้กรอก)
  static String incomeReceiptNoMustBeSequentialNext(String nextFormatted) =>
      'เลขที่ใบเสร็จต้องเรียงต่อเนื่องจากใบก่อนหน้าในเล่มเดียวกัน (เลขที่ถัดไป: $nextFormatted)';

  /// แสดงใต้ช่องเลขที่ใบเสร็จเมื่อเลือกเล่มแล้ว
  static String incomeReceiptNoSuggestedNext(String nextFormatted) =>
      'เลขที่ถัดไปที่ควรใช้: $nextFormatted';
  static const incomeReceiptNoHint = 'เลขในเล่มที่ออกครั้งนี้';
  static String incomeReceiptNoMustMatchBookFormat(String example) =>
      'รูปแบบเลขที่ใบเสร็จต้องตรงกับรูปแบบของเล่ม (ตัวอย่าง: $example)';
  static String incomeReceiptNoExceedsBookEnd(String endNo) =>
      'เลขที่ใบเสร็จต้องไม่เกินเลขที่สุดท้ายของเล่ม ($endNo)';
  static const incomeBankAccountLabel = 'บัญชีธนาคารรับเงิน';
  static const incomeSaveOnly = 'บันทึกอย่างเดียว';
  static const incomeSaveAndPrintReceipt = 'บันทึกและพิมพ์ใบเสร็จ';
  static const incomeReceiptPrintCopyTitle = 'ข้อมูลสำหรับพิมพ์ใบเสร็จ';
  static const incomeBudgetLinkedAuto = 'แหล่งเงินที่ผูกกับหมวดนี้';
  static const incomeSelectBankIfTransfer =
      'กรุณาเลือกบัญชีธนาคารเมื่อรับเป็นเงินโอน';
  static const incomeSelectBankOrSetBudgetSourceBank =
      'เมื่อรับผ่านธนาคาร ต้องตั้งบัญชีที่แหล่งเงินที่เลือก หรือเลือกบัญชีเฉพาะใบนี้';
  static const incomeBankDocumentOverrideHelper =
      'ว่างได้หากแหล่งเงินที่เลือกมีบัญชีแล้ว — เลือกที่นี่เฉพาะเมื่อต้องการบังคับใบนี้';
  static const incomeTypeBudgetLinkFieldLabel =
      'แหล่งเงินที่ต้องการผูกกับหมวดนี้ *';
  static const incomeTypeBudgetLinkHint =
      'แตะเลือก — หลายรายการได้เฉพาะแยกปีงบหรือสายโครงการภายใต้ประเภทเดียวกัน';
  static const incomeTypeBudgetLinkManualHelper =
      'คู่มือ (พ.ศ. 2544): แยกทะเบียนตามประเภทเงิน — ผูกเฉพาะแหล่งในสายเดียวกับหมวด; ถ้าคู่มือถือเป็นคนละประเภท ให้ใช้คนละหมวดรายรับ ไม่รวมหลายประเภทในหมวดเดียว';
  static const incomeTypeBudgetLinkMoneyGroupRequiredForMany =
      'ผูกหลายแหล่งเงิน: ต้องกำหนดกลุ่มเงิน (ประเภทเงิน) ให้ครบทุกแหล่งก่อน — ตามหลักทะเบียนคุมแยกประเภท';
  static const incomeTypeBudgetLinkMoneyGroupConflict =
      'ผูกหลายแหล่งเงินได้เฉพาะเมื่อเป็นประเภทเงิน (กลุ่มเงิน) เดียวกัน — แหล่งที่เลือกไม่ตรงกัน';
  static const incomeTypeBudgetLinkBudgetTypeConflict =
      'ผูกหลายแหล่งเงินได้เฉพาะเมื่อเป็นประเภทงบ (budget_type) เดียวกัน — แหล่งที่เลือกไม่ตรงกัน';
  static const incomeTypeBudgetLinkPriorIncomeTypeConflict =
      'แหล่งเงินที่เลือกเคยผูกหมวดรายรับคนละหมวด — แยกหมวดหรือเลือกเฉพาะแหล่งในสายเดียวกันตามคู่มือ';
  static const incomeTypeBudgetLinkFundCategoryMixed =
      'แหล่งบางรายการยังไม่ผูกหมวด บางรายการผูกแล้ว — เลือกให้สอดคล้องกันก่อนบันทึก';
  static const incomeTypeBudgetLinkMasterNotFound =
      'ไม่พบข้อมูลแหล่งเงินบางรายการ';
  static const incomeReceiptFieldsIncomplete =
      'กรุณาเลือกเล่มและกรอกเลขที่ใบเสร็จให้ครบ';
  static const incomeReceiveFromFreeOrMasterHint =
      'พิมพ์ชื่อผู้จ่ายได้ หรือกดไอคอนรายการเพื่อเลือกจากทะเบียน';
  static const incomeNoReceiptBooksHint =
      'ยังไม่มีเล่มใบเสร็จที่พร้อมใช้ — เพิ่มเล่มได้จากเมนูทะเบียนคุม';
  static const incomeNoReceiptBooksGoManage = 'ไปเพิ่มเล่มใบเสร็จ';
  static const incomeReceiptBooksRefreshedReady =
      'รีเฟรชเล่มใบเสร็จแล้ว สามารถเลือกเล่มได้';
  static const incomeReceiptBooksRefreshedStillEmpty =
      'ยังไม่มีเล่มใบเสร็จที่พร้อมใช้';
  static const incomeNoBankAccountsHint =
      'ยังไม่มีบัญชีธนาคารในระบบ — เพิ่มได้จากหน้าจัดการหมวดรายรับ';

  // Auth / Login
  static const appThaiName = 'ระบบบัญชีและการเงินสถานศึกษา';
  static const appEnglishSubtitle = 'SACCM — School Accounting & Finance';
  static const appFooterWelcome = 'ยินดีต้อนรับ';
  static const appFooterUnknownUser = 'ผู้ใช้งาน';
  static const appFooterFullNameLabel = 'ชื่อเต็ม';
  static const appFooterUserDetailTitle = 'รายละเอียดผู้ใช้งาน';
  static const appFooterSchoolDetailTitle = 'ข้อมูลโรงเรียน';
  static const appFooterClickForDetails = 'คลิกเพื่อดูรายละเอียด';
  static const appFooterVersionLabel = 'Version';
  static const appFooterApiOnline = 'API Online';
  static const appFooterApiOffline = 'ทำงาน Offline';
  static const appFooterApiOnlineTooltip = 'เชื่อมต่อ API พร้อมใช้งาน';
  static const appFooterApiOfflineTooltip =
      'ไม่สามารถเชื่อมต่อ API ได้ ขณะนี้ใช้งานข้อมูลในเครื่อง';
  static const appFooterModeTrialOfflineTooltip =
      'โหมดทดลองใช้ทำงานแบบ Offline เท่านั้น';
  static const appFooterModeOfflineLicenseTooltip =
      'แพ็กเกจออฟไลน์ทำงานบนเครื่อง ไม่ตรวจ API';
  static const appFooterModeOnlineLicenseOnlineTooltip =
      'แพ็กเกจออนไลน์+ออฟไลน์: API พร้อมใช้งาน';
  static const appFooterModeOnlineLicenseOfflineTooltip =
      'แพ็กเกจออนไลน์+ออฟไลน์ แต่ตอนนี้เชื่อมต่อ API ไม่ได้ จึงทำงาน Offline';
  static const appFooterAdminRole = 'ผู้ดูแลระบบ';
  static const appFooterOfficerRole = 'เจ้าหน้าที่';
  static const appFooterSchoolNotSet = 'ยังไม่ได้ตั้งค่าข้อมูลโรงเรียน';
  static String appFooterTrialDaysRemaining(int days) =>
      'ทดลองใช้เหลือ $days วัน';
  static String appFooterTrialTooltip(int remaining, int total) =>
      'ทดลองใช้บนเครื่อง เหลือ $remaining / $total วัน';
  static const appFooterTrialExpired = 'หมดช่วงทดลองใช้';
  static const appFooterActivatedOffline = 'Activate: ออฟไลน์';
  static const appFooterActivatedOnline = 'Activate: ออนไลน์+ออฟไลน์';
  static const appFooterLicenseExpired = 'License หมดอายุ';
  static const username = 'ชื่อผู้ใช้';
  static const usernameHint = 'กรอกชื่อผู้ใช้';
  static const password = 'รหัสผ่าน';
  static const passwordHint = 'กรอกรหัสผ่าน';
  static const rememberPassword = 'จำรหัสผ่าน';
  static const offlineModeMessage = 'ทำงาน Offline ด้วยข้อมูลบันทึกไว้';
  static const localOnlyModeTitle = 'โหมด Local';
  static const localOnlyModeMessage =
      'ใช้ข้อมูลบนเครื่องนี้ — ทดลองใช้ฝังในแอป (ไม่ต้องลงทะเบียน) จนกว่าจะหมดอายุหรือเลือกลงทะเบียนออนไลน์';
  static String embeddedTrialLoginBanner(int daysLeft, int totalDays) =>
      'ทดลองใช้บนเครื่อง — เหลือ $daysLeft / $totalDays วัน (ไม่ต้องลงทะเบียน)';
  static const embeddedTrialStatusTitle = 'ทดลองใช้บนเครื่อง';
  static const embeddedTrialStatusLead =
      'นับจากวันแรกที่เปิดแอป — กำหนดในโปรแกรม ไม่ผ่าน Registry';
  static const embeddedTrialDaysTotal = 'ระยะทดลอง';
  static const embeddedTrialDaysRemaining = 'เหลือ (วัน)';
  static const embeddedTrialExpiredTitle = 'หมดระยะทดลองใช้บนเครื่องแล้ว';
  static String embeddedTrialExpiredMessage(int days) =>
      'ใช้งานทดลอง $days วันครบแล้ว — กรุณาลงทะเบียนออนไลน์ด้วยรหัสจากผู้ให้บริการเพื่อใช้งานต่อ';
  static const licenseActivateOptionalTitle = 'ลงทะเบียนแพ็กเกจด้วยรหัส';
  static const licenseActivateOptionalSubtitle =
      'ใช้เมื่อซื้อแพ็กเกจออฟไลน์หรือออนไลน์+ออฟไลน์ — ทดลองใช้ไม่ต้องลงทะเบียน';
  static const login = 'เข้าสู่ระบบ';
  static const loginHelp = 'หากเข้าสู่ระบบไม่ได้ กรุณาติดต่อผู้ดูแลระบบ';
  static const fillUsername = 'กรุณากรอกชื่อผู้ใช้';
  static const fillPassword = 'กรุณากรอกรหัสผ่าน';
  static const passwordMinLength = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
  static const changeInitialPasswordTitle = 'เปลี่ยนรหัสผ่านเริ่มต้น';
  static const changeInitialPasswordMessage =
      'เพื่อความปลอดภัย กรุณาเปลี่ยนรหัสผ่านก่อนเข้าใช้งานระบบ';
  static const newPassword = 'รหัสผ่านใหม่';
  static const confirmPassword = 'ยืนยันรหัสผ่านใหม่';
  static const passwordMismatch = 'รหัสผ่านใหม่ไม่ตรงกัน';
  static const changePassword = 'เปลี่ยนรหัสผ่าน';
  static const userDisabled = 'บัญชีผู้ใช้นี้ถูกปิดการใช้งาน';
  static const disableUser = 'ปิดการใช้งานผู้ใช้';
  static const enableUser = 'เปิดการใช้งานผู้ใช้';
  static const editUserRole = 'แก้ไขสิทธิ์ผู้ใช้';
  static const cannotDisableCurrentUser =
      'ไม่สามารถปิดการใช้งานบัญชีที่กำลังล็อกอินอยู่';
  static const cannotDowngradeCurrentAdmin =
      'ไม่สามารถลดสิทธิ์บัญชีผู้ดูแลที่กำลังล็อกอินอยู่';
  static const auditLogs = 'ประวัติการใช้งาน';
  static const auditLogsSubtitle = 'ตรวจสอบการแก้ไขสิทธิ์และผู้ใช้ย้อนหลัง';
  static const exportCsv = 'ส่งออก CSV';
  static const exportExcel = 'ส่งออก Excel';
  static const fromDate = 'จากวันที่';
  static const toDate = 'ถึงวันที่';
  static const clearFilters = 'ล้างตัวกรอง';
  static const resultCount = 'ผลลัพธ์';
  static const autoGenerateCode = 'สร้างรหัสอัตโนมัติ';
  static const budgetCodeFormatHint = 'รูปแบบรหัส: SRC-GOV-2569-001';
  static const budgetCodeInvalidFormat = 'รูปแบบรหัสไม่ถูกต้อง';
  static const budgetCodeDuplicate = 'รหัสแหล่งเงินซ้ำในระบบ';

  // Setting API/DB
  static const apiDbSettingTitle = 'ตั้งค่า API';
  static const apiDbSettingSubtitle = 'กำหนดการเชื่อมต่อกับเซิร์ฟเวอร์';
  static const apiConfigSection = 'API Configuration';
  static const apiUrl = 'API URL';
  static const apiUrlHint = 'เช่น http://localhost:3801';
  static const apiSettingRequiresOnlineLicense =
      'ต้องลงทะเบียนแพ็กเกจออนไลน์+ออฟไลน์ก่อนจึงจะตั้งค่า API ได้';
  static const apiSettingLockedTitle = 'ยังไม่มีสิทธิ์ตั้งค่า API';
  static const apiSettingLockedMessage =
      'การเชื่อมต่อ API ใช้ได้เฉพาะเครื่องที่ลงทะเบียนแพ็กเกจออนไลน์+ออฟไลน์แล้วเท่านั้น';
  static const apiSettingGoProductPlan = 'ดูแพ็กเกจ / ลงทะเบียน';

  // Database health
  static const dbHealthTitle = 'ตรวจสุขภาพฐานข้อมูล';
  static const dbHealthSubtitle =
      'ตรวจความสัมพันธ์ข้อมูล SQLite และส่งออกรายงานสำหรับแก้ปัญหา';
  static const dbHealthCopySummaryTooltip = 'คัดลอกรายงานสรุป';
  static const dbHealthCopiedCsv = 'คัดลอก CSV ลงคลิปบอร์ดแล้ว';
  static const dbHealthCopiedSummary = 'คัดลอกรายงานสรุปแล้ว';
  static const dbHealthOpenExportFolder = 'เปิดโฟลเดอร์ไฟล์';
  static const dbHealthRelationshipOk =
      'ความสัมพันธ์ฐานข้อมูลปกติ (ไม่พบปัญหา)';
  static String dbHealthRelationshipIssueCount(int totalIssues) =>
      'พบปัญหาความสัมพันธ์รวม $totalIssues จุด';
  static const dbHealthSummaryTitle = 'สรุปรายงานสุขภาพฐานข้อมูล';
  static String dbHealthTotalIssues(int totalIssues) =>
      'ปัญหารวม: $totalIssues';
  static const dbHealthSummaryOk = 'สถานะ: ปกติ (ไม่พบปัญหา)';
  static const dbHealthTopIssues = 'รายการที่มีปัญหาสูงสุด:';
  static String dbHealthSavedTo(String path) => 'บันทึกไฟล์แล้ว: $path';
  static const dbHealthExportFailed = 'ส่งออกรายงานไม่สำเร็จ';
  static const dbHealthLoadFailed = 'โหลดรายงานสุขภาพฐานข้อมูลไม่สำเร็จ';
  static const dbHealthNoRelationships = 'ไม่มีรายการตรวจสอบ';
  static const dbHealthCsvHeader = 'relation,issue_count,status';
  static const dbHealthStatusOk = 'OK';
  static const dbHealthStatusError = 'ERROR';

  // เปิดใช้งานออนไลน์ (license)
  static const licenseActivationTitle = 'เปิดใช้งาน SACCM';
  static const licenseActivationLead =
      'กรอกรหัสเปิดใช้งานที่ได้รับจากผู้ให้บริการ และตั้งบัญชีผู้ดูแลระบบครั้งแรก (ต้องเชื่อมอินเทอร์เน็ต)';
  static const licenseKeyLabel = 'รหัสเปิดใช้งาน';
  static const licenseKeyHint = 'SACC-XXXX-XXXX-XXXX';
  static const licenseDeviceLabel = 'ชื่อเครื่องนี้';
  static const licenseAdminSection = 'บัญชีผู้ดูแลระบบ (ครั้งแรก)';
  static const licenseAdminName = 'ชื่อ';
  static const licenseAdminLastname = 'นามสกุล';
  static const licenseAdminEmail = 'อีเมล (ไม่บังคับ)';
  static const licenseActivateButton = 'เปิดใช้งานและไปหน้าเข้าสู่ระบบ';
  static const licenseInfoTitle = 'สถานะการเปิดใช้งาน';
  static const licenseInfoSubtitle = 'รหัสโรงเรียน จำนวนเครื่อง และการซิงก์';
  static const licenseNotActivated = 'ยังไม่ได้เปิดใช้งานออนไลน์';
  static const licenseSchoolName = 'โรงเรียน';
  static const licenseSchoolCode = 'รหัสโรงเรียน';
  static const licenseStatusLabel = 'สถานะ';
  static const licenseDevices = 'เครื่องที่ใช้';
  static const licenseThisDevice = 'เครื่องนี้ลงทะเบียนแล้ว';
  static const licenseCanSync = 'ซิงก์ออนไลน์ได้';
  static const licenseExpiredWarning = 'ใบอนุญาตหมดอายุ — ติดต่อผู้ให้บริการ';
  static const licenseAdminTitle = 'จัดการรหัสเปิดใช้งาน';
  static const licenseAdminSubtitle = 'สำหรับผู้ให้บริการ (server กลาง)';
  static const licenseAdminSecretLabel = 'รหัสผู้ดูแล (Admin Secret)';
  static const licenseAdminSecretHint = 'ตรงกับ LICENSE_ADMIN_SECRET บน server';
  static const licenseAdminGenerate = 'สร้างรหัสใหม่';
  static const licenseAdminRevoke = 'ยกเลิก';
  static const licenseAdminSchoolName = 'ชื่อโรงเรียน (สร้างรหัสใหม่)';
  static const licenseAdminMaxDevices = 'จำนวนเครื่องสูงสุด';
  static const licenseAdminDays = 'อายุ (วัน)';
  static const licenseAdminGeneratedKey = 'รหัสที่สร้าง (คัดลอกเก็บไว้)';
  static const licenseKindLabel = 'ประเภทใบอนุญาต';
  static const licenseKindTrial = 'ทดลองใช้ (90 วัน)';
  static const licenseKindStandard = 'มาตรฐาน';
  static const licenseExpiresLabel = 'หมดอายุ';
  static const licenseAdminTrialMode = 'ทดลองใช้ (trial)';
  static const licenseAdminIssueLogs = 'บันทึกการออกรหัส';
  static const licenseAdminActivationLogs = 'บันทึกการเปิดใช้งาน';

  // แพ็กเกจการขาย (3 ระดับ)
  static const productPlanTitle = 'ทดลองใช้ / แพ็กเกจ';
  static const productPlanSettingSubtitle =
      'ดูสถานะทดลองใช้และลงทะเบียนแพ็กเกจซื้อแล้ว';
  static const productPlanLead =
      'ทดลองใช้เป็นโหมดชั่วคราวในเครื่อง ส่วนแพ็กเกจซื้อแล้วต้องลงทะเบียนด้วยรหัส SACC จากผู้ให้บริการ';
  static const productPlanOptionsTitle = 'แพ็กเกจที่เลือกได้';
  static const productPlanOptionsSubtitle =
      'เปรียบเทียบโหมดทดลองใช้ ออฟไลน์ และออนไลน์ก่อนลงทะเบียน';
  static const productTierCurrentBadge = 'แพ็กเกจปัจจุบัน';
  static const productTierTrialCurrentBadge = 'กำลังทดลองใช้';
  static const productTierRecommendedBadge = 'แนะนำ';
  static const productPlanCurrentStatusBadge = 'สถานะปัจจุบัน';
  static const productTierActivateLicense = 'ลงทะเบียนด้วยรหัส';
  static const productTierTrialTitle = 'ทดลองใช้';
  static String productTierTrialSubtitle(int days) =>
      'ฟรี $days วัน — โหมดทดลองใช้ในเครื่อง ไม่ใช่แพ็กเกจออฟไลน์ที่ซื้อแล้ว';
  static List<String> productTierTrialFeatures(int days) => [
        'เปิดใช้ได้ทันทีวันแรก',
        'ข้อมูลเก็บบนเครื่อง (SQLite)',
        'ไม่ต้องเชื่อม Registry',
        'ครบ $days วันแล้วต้องซื้อและลงทะเบียนแพ็กเกจเพื่อใช้งานต่อ',
      ];
  static const productTierOfflineTitle = 'ออฟไลน์ (ซื้อแล้ว)';
  static const productTierOfflineSubtitle =
      'แพ็กเกจซื้อแล้ว — ลงทะเบียนด้วยรหัส ใช้งานบนเครื่องต่อเนื่อง ไม่ซิงก์ server';
  static const List<String> productTierOfflineFeatures = [
    'รหัสจากผู้ให้บริการ (Registry)',
    'ข้อมูลอยู่บนเครื่องเท่านั้น',
    'ไม่ต้องมี server ออนไลน์ตอนใช้งาน',
    'จำกัดจำนวนเครื่องตามรหัส',
  ];
  static const productTierOnlineTitle = 'ออนไลน์ + ออฟไลน์';
  static const productTierOnlineSubtitle =
      'ลงทะเบียน + ซิงก์ข้อมูลกับ server กลาง';
  static const List<String> productTierOnlineFeatures = [
    'ทุกอย่างในแพ็กเกจออฟไลน์',
    'ซิงก์ข้อมูลมาตรฐาน / รายการกับ server',
    'หลายเครื่องในโรงเรียนเดียวกัน',
    'เหมาะกับ pilot หลายจุด',
  ];
  static const licenseKeyPreviewOffline = 'รหัสนี้: แพ็กเกจออฟไลน์';
  static const licenseKeyPreviewOnline = 'รหัสนี้: แพ็กเกจออนไลน์+ออฟไลน์';
  static const licenseKeyPreviewInvalid = 'รหัสไม่ถูกต้องหรือหมดอายุ';
  static const licenseAdminProductTier = 'แพ็กเกจที่ออกรหัส';
  static const licenseAdminTierOffline = 'ออฟไลน์';
  static const licenseAdminTierOnline = 'ออนไลน์+ออฟไลน์';
  static const licenseActivateNeedsInternet =
      'ต้องเชื่อมอินเทอร์เน็ตเพื่อตรวจรหัสกับผู้ให้บริการ (ครั้งแรกเท่านั้น)';
  static const licenseExpiredBlockedTitle = 'ใบอนุญาตหมดอายุหรือถูกยกเลิก';
  static const licenseExpiredBlockedMessage =
      'ติดต่อผู้ให้บริการเพื่อต่ออายุหรือออกรหัสใหม่ แล้วลงทะเบียนอีกครั้ง';
  static const licenseOfflineAfterActivateHint =
      'หลังลงทะเบียนแล้ว แพ็กเกจออฟไลน์ใช้งานบนเครื่องได้โดยไม่ต้องมีอินเทอร์เน็ต';
  static const licenseLoginSchoolBanner = 'เปิดใช้งานแล้ว';
  static const masterDataSyncTitle = 'ซิงก์ข้อมูลมาตรฐาน';
  static const masterDataSyncInProgress =
      'กำลังดึงข้อมูลมาตรฐานจากเซิร์ฟเวอร์…';
  static const masterDataSyncSuccess = 'ซิงก์ข้อมูลมาตรฐานสำเร็จ';
  static const masterDataSyncFailed =
      'ซิงก์ข้อมูลมาตรฐานไม่สำเร็จ — ลองใหม่เมื่อออนไลน์';
  static const masterDataSyncAfterActivate = 'กำลังเตรียมข้อมูลเริ่มต้น…';
  static const sessionTokenRefreshed =
      'เชื่อมต่อเซิร์ฟเวอร์แล้ว (อัปเดต session)';

  // ── ระบบกันแกะโค๊ด (code protection) ──────────────────────────────
  /// แสดงเมื่อตรวจพบไฟล์โปรแกรมถูกแก้ไข (integrity ไม่ผ่าน)
  static const guardTamperTitle = 'ตรวจพบความผิดปกติของโปรแกรม';
  static const guardTamperMessage =
      'ไฟล์โปรแกรมอาจถูกแก้ไขหรือเสียหาย เพื่อความปลอดภัยของข้อมูล '
      'ระบบจึงหยุดการทำงาน กรุณาติดตั้งโปรแกรมใหม่จากแหล่งที่เป็นทางการ';

  /// แสดงเมื่อตรวจพบการดีบัก/แกะโปรแกรมขณะรัน
  static const guardDebuggerTitle = 'ไม่สามารถเปิดโปรแกรมในโหมดนี้ได้';
  static const guardDebuggerMessage =
      'ตรวจพบเครื่องมือวิเคราะห์/ดีบักโปรแกรมกำลังทำงานอยู่ '
      'กรุณาปิดเครื่องมือดังกล่าวแล้วเปิดโปรแกรมใหม่อีกครั้ง';

  static const guardExitButton = 'ปิดโปรแกรม';
  static const guardRetryButton = 'ลองใหม่';

  static const labelYes = 'ใช่';
  static const labelNo = 'ไม่';
  static const testApi = 'ทดสอบ API';
  static const testing = 'กำลังทดสอบ...';
  static const apiReady = 'API พร้อมใช้งาน';
  static const apiInvalidResponse = 'API ตอบกลับผิดพลาด';
  static const fillRequiredFields = 'กรุณากรอกข้อมูลให้ครบถ้วน';
  static const saveConfigSuccess = 'บันทึกการตั้งค่าเรียบร้อย';
  static const settings = 'การตั้งค่า';
  static const defaults = 'ค่าเริ่มต้น';
  static const systemSettings = 'การตั้งค่าระบบ';
  static const manageDataAndSettings = 'จัดการข้อมูลและการตั้งค่าต่าง ๆ';
  static const general = 'ทั่วไป';

  /// ตั้งค่าระบบ → ทั่วไป — ชื่อ ที่ตั้ง โทรศัพท์ ฯลฯ (เก็บบนเครื่อง)
  static const schoolProfileTitle = 'ข้อมูลโรงเรียน';
  static const schoolProfileSubtitle = 'ตั้งค่าชื่อและที่ตั้งสำหรับใช้ในรายงาน';
  static const schoolProfileLocalNote =
      'ข้อมูลนี้บันทึกในเครื่องนี้เท่านั้น ไม่ซิงก์ไปเซิร์ฟเวอร์โดยอัตโนมัติ — ชื่อโรงเรียนแสดงในหน้าหลัก หน้ารายงาน และบรรทัดอธิบายตอนต้นของไฟล์ CSV เมื่อส่งออก';
  static const schoolProfileRequiredBeforeSaveHint =
      'กรอกชื่อโรงเรียนให้ครบก่อนบันทึก ข้อมูลนี้ใช้แสดงในหน้าหลักและรายงาน';
  static const schoolProfileMainSection = 'ข้อมูลหลัก';
  static const schoolProfileContactSection = 'ข้อมูลติดต่อและหมายเหตุ';
  static const schoolProfileNameLabel = 'ชื่อโรงเรียน';
  static const schoolProfileNameHint = 'เช่น โรงเรียนบ้านพักครู';
  static const schoolProfileAddressLabel = 'ที่ตั้ง / ที่อยู่';
  static const schoolProfileAddressHint =
      'เลขที่ ถนน ตำบล อำเภอ จังหวัด รหัสไปรษณีย์';
  static const schoolProfilePhoneLabel = 'โทรศัพท์';
  static const schoolProfilePhoneHint = 'เช่น 02-xxx-xxxx';
  static const schoolProfileExtraLabel = 'ข้อมูลอื่น ๆ';
  static const schoolProfileExtraHint =
      'เช่น เลขประจำตัวผู้เสียภาษี ผู้อำนวยการ หรือหมายเหตุ';
  static const schoolProfileSaveSuccess = 'บันทึกข้อมูลโรงเรียนเรียบร้อย';
  static const schoolProfileReadyToSave = 'พร้อมบันทึกข้อมูลโรงเรียนแล้ว';
  static const schoolProfileMissingRequiredPrefix = 'กรุณากรอก: ';
  static const schoolProfileUnsavedLeaveTitle = 'ออกจากหน้านี้?';
  static const schoolProfileUnsavedLeaveBody =
      'มีข้อมูลโรงเรียนที่ยังไม่ได้บันทึก ต้องการออกโดยไม่บันทึกหรือไม่';
  static const userManagement = 'การจัดการผู้ใช้';
  static const finance = 'การเงิน';
  static const setDefaultSystem = 'กำหนดค่าตั้งต้นของระบบ';
  static const systemUsers = 'ผู้เข้าใช้งานระบบ';
  static const userAccountManage = 'เพิ่ม/แก้ไขบัญชีผู้ใช้งาน';
  static const members = 'สมาชิก';
  static const cooperativeMembersManage = 'จัดการข้อมูลสมาชิก';
  static const addMember = 'เพิ่มสมาชิก';
  static const editMember = 'แก้ไขสมาชิก';
  static const memberFormHint =
      'เพิ่มหรือแก้ไขข้อมูลสมาชิกสำหรับใช้อ้างอิงในงานการเงินและรายงาน';
  static const memberRequiredBeforeSaveHint =
      'กรอกรหัส ชื่อ และนามสกุลให้ครบก่อนบันทึก';
  static const memberReadyToSave = 'ข้อมูลสมาชิกพร้อมบันทึก';
  static const memberProfileSection = 'ข้อมูลสมาชิก';
  static const memberListSection = 'รายการสมาชิก';
  static const incomeTypeTitle = 'หมวดรายรับ';
  static const incomeTypeManage =
      'กำหนดหมวดรายรับ พร้อมเลือกแหล่งเงินที่เกี่ยวข้อง';
  static const incomeTypeUnlinkedChip = 'ยังไม่ผูกแหล่งเงิน';
  static const incomeTypeUnlinkedWarningTitle =
      'มีหมวดรายรับที่ยังไม่ผูกแหล่งเงิน';
  static const incomeTypeUnlinkedWarningBody =
      'หมวดเหล่านี้จะใช้บันทึกรายรับไม่ได้จนกว่าจะผูกแหล่งเงินอย่างน้อย 1 รายการ';
  static const incomeTypeFilterUnlinkedOnly = 'แสดงเฉพาะหมวดที่ยังไม่ผูก';
  static const incomeTypeFilterShowAll = 'แสดงทั้งหมด';
  static const incomeTypeListLoadingBusy = 'กำลังโหลดหมวดรายรับ...';
  static const incomeTypeListEmpty = 'ยังไม่มีหมวดรายรับ';
  static const incomeTypeListRetry = 'โหลดข้อมูลอีกครั้ง';
  static const incomeTypeEdit = 'แก้ไขหมวดรายรับ';
  static String incomeTypeDeleteConfirmQuestion(String name) =>
      'ต้องการลบหมวดรายรับ "$name" หรือไม่?';
  static const incomeTypeBudgetSourceRequired =
      'กรุณาผูกแหล่งเงินอย่างน้อย 1 รายการก่อนบันทึกหมวดรายรับ';
  static const incomeTypeSavingBusy = 'กำลังบันทึกหมวดรายรับ...';
  static const incomeTypeUpdatingBusy = 'กำลังบันทึกการแก้ไขหมวดรายรับ...';
  static const incomeTypeDeletingBusy = 'กำลังลบหมวดรายรับ...';
  static const incomeTypeSearchHint = 'ค้นหาชื่อหมวด/รหัส/หมายเหตุ...';
  static const incomeTypeSortNameAsc = 'ชื่อ (ก-ฮ)';
  static const incomeTypeSortLinkedDesc = 'ผูกแหล่งเงินมากสุด';
  static const incomeTypeSortUpdatedDesc = 'อัปเดตล่าสุด';
  static const incomeTypeBudgetSourcesEmptyHint = 'ยังไม่มีแหล่งเงินในระบบ';
  static const incomeTypeBudgetSourcesEmptyHelper =
      'กรุณาเพิ่มแหล่งเงินก่อน จึงจะผูกกับหมวดรับได้';
  static const incomeTypeGoAddBudgetSource = 'ไปเพิ่มแหล่งเงิน';
  static const incomeTypeSelectBudgetSourcesTitle = 'เลือกแหล่งเงิน';
  static const incomeTypeEditorDismissConfirmTitle = 'ปิดแบบฟอร์ม?';
  static const incomeTypeEditorDismissConfirmMessage =
      'การแก้ไขที่ยังไม่บันทึกจะหายไป ต้องการปิดหรือไม่';
  static const incomeTypeRowMenuTooltip = 'จัดการรายการ';
  static String incomeTypeLinkedSourcesLabel(int count) =>
      'ผูกแหล่งเงิน $count';
  static String incomeTypeCodeLine(String code) => 'รหัส: $code';
  static const detailTapToExpand = 'แตะเพื่ออ่านทั้งหมด';
  static const detailTapToCollapse = 'แตะเพื่อย่อ';
  static const budgetSourceTitle = 'แหล่งเงิน';
  static const budgetSourceManage = 'กำหนดแหล่งเงินและวงเงินรายปี';
  static const budgetDashboardTitle = 'ภาพรวมงบประมาณ';
  static const budgetDashboardOverviewTitle = 'สรุปวงเงิน';
  static String budgetDashboardFiscalYearLine(String fiscalYear) =>
      'ปีงบประมาณ $fiscalYear';
  static const budgetDashboardTotalBudget = 'วงเงินรวม';
  static const budgetDashboardTotalUsed = 'ใช้ไปแล้ว';
  static const budgetDashboardTotalReserved = 'กันไว้';
  static const budgetDashboardAvailable = 'ใช้ได้จริง';
  static const budgetDashboardSourcesSection = 'รายการแหล่งเงิน';
  static const budgetDashboardMockHint = 'ข้อมูลจำลองสำหรับแสดงตัวอย่าง';

  /// แดชบอร์ดอ่านจาก SQLite จริง (master + งบรายปี)
  static const budgetDashboardLiveDataHint =
      'ข้อมูลจากฐานในเครื่อง — สรุปจาก budget_source_master และ budget_source_budget';
  static const budgetDashboardSelectFiscalYear = 'เลือกปีงบประมาณ';
  static const budgetDashboardEmptyForYear =
      'ยังไม่มีแหล่งเงินในปีนี้ — เปิดรายการแหล่งเงินแล้วกดเพิ่มรายการ';

  /// คำอธิบายใต้หัวข้อหน้ารายการแหล่งเงิน
  static const budgetSourceListIntro =
      'แต่ละการ์ดคืองบในแต่ละปี (ตาราง budget_source_budget) เชื่อมกับแหล่งเงินหลัก (master) ประเภทเงิน และบัญชีธนาคาร';
  static const budgetSourceSortRemainingAvailable = 'คงเหลือใช้ได้: มากไปน้อย';
  static const budgetSourceFilterSectionTitle = 'ค้นหาและตัวกรอง';
  static const budgetSourceSortLabel = 'เรียงลำดับ';
  static const budgetSourceFilterAllYears = 'ทุกปี';
  static const budgetSourceFilterActiveHint = 'มีตัวกรองที่ใช้งานอยู่';
  static const budgetDashboardLegendUsed = 'ใช้ไปแล้ว';
  static const budgetDashboardLegendReserved = 'กันไว้';
  static const budgetDashboardLegendAvailable = 'คงเหลือ';
  static const budgetDashboardOpenTooltip = 'เปิดภาพรวมงบประมาณ';
  static const budgetDashboardOfCapSuffix = 'ของวงเงินรวม';
  static const selectBudgetSource = 'กรุณาเลือกแหล่งเงิน';
  static const expenseTypeTitle = 'ประเภทรายจ่าย';
  static const selectExpenseType = 'เลือกประเภทรายจ่าย';
  static const expenseTypeHelperText =
      'ตามระเบียบพัสดุ เช่น ค่าวัสดุ ค่าใช้สอย';
  static const expenseTypeManage = 'เพิ่มประเภทรายจ่าย';
  static const expenseTypeEdit = 'แก้ไขประเภทรายจ่าย';
  static const expenseTypeEditorDismissConfirmTitle = 'ปิดแบบฟอร์ม?';
  static const expenseTypeEditorDismissConfirmMessage =
      'การแก้ไขที่ยังไม่บันทึกจะหายไป ต้องการปิดหรือไม่';
  static const expenseTypeName = 'ชื่อประเภทรายจ่าย';
  static const expenseTypeCode = 'รหัสประเภท';
  static const expenseTypeNameRequired = 'ชื่อประเภทรายจ่ายต้องไม่เป็นค่าว่าง';
  static const expenseTypeManageSubtitle =
      'แถวในตาราง expense_type (ประเภท พ.ศ. 2560) — คนละความหมายกับหมวดรายรับหรือหมวดทะเบียนคุม OB';
  static const expenseTypeListLoadingBusy = 'กำลังโหลดประเภทรายจ่าย...';
  static const expenseTypeListEmpty = 'ยังไม่มีประเภทรายจ่าย';
  static const expenseTypeSemanticsFootnote =
      'ใช้คำว่า “ประเภทรายจ่าย” ให้ตรงตาราง expense_type — ไม่เรียกว่า “หมวดรายจ่าย” เพื่อไม่สับสนกับหมวดรายรับ (income_type) และหมวดทะเบียนคุมนอกงบฯ';
  static const expenseTypeDefaultBudgetLabel = 'แหล่งงบเริ่มต้น';

  static String expenseTypeDeleteConfirmQuestion(String name) =>
      'ต้องการลบประเภทรายจ่าย "$name" หรือไม่?\nหากมีรายการเบิกจ่ายที่ใช้ประเภทนี้ระบบจะไม่อนุญาตให้ลบ';

  static String expenseTypeDefaultBudgetSummary({
    required String masterLabel,
    required String fiscalYear,
  }) =>
      '$expenseTypeDefaultBudgetLabel: $masterLabel · ปีงบ $fiscalYear';

  static const expenseTypeDefaultBudgetRequired = 'ต้องเลือกแหล่งเงินเริ่มต้น';
  static const expenseTypeNoBudgetSourcesHint =
      'ยังไม่มีแหล่งเงินในระบบ — ตั้งค่าแหล่งเงินก่อน จึงจะเพิ่มประเภทรายจ่ายได้';
  static const expenseTypeOpenBudgetSourcePage = 'ไปตั้งค่าแหล่งเงิน';
  static const expenseTypeDefaultBudgetMissingOnCard =
      'ยังไม่ผูกแหล่งเงินเริ่มต้น — แตะแก้ไขแล้วเลือกแหล่งเงิน';

  static const systemConnection = 'การเชื่อมต่อระบบ';
  static const appTheme = 'ธีมแอป';
  static const quickActions = 'เมนูลัด';
  static const allSettings = 'การตั้งค่าทั้งหมด';
  static const incomeTypeQuickAddTitle = 'เพิ่มหมวดรายรับ';
  static const incomeTypeQuickAddSubtitle =
      'เปิด popup เพื่อเพิ่มหมวดรายรับเป็นค่าพื้นฐานของระบบ';
  static const incomeTypeQuickAddChip = 'เพิ่มหมวดรายรับ';
  static const incomeTypeQuickAddDialogTitle =
      'เพิ่มหมวดรายรับ (ค่าพื้นฐานระบบ)';
  static const incomeTypeQuickAddSuccess = 'เพิ่มหมวดรายรับเรียบร้อย';
  static const settingSearchLabel = 'ค้นหาเมนูตั้งค่า';
  static const settingSearchHint = 'พิมพ์ชื่อเมนู เช่น ธีม หรือ การเชื่อมต่อ';
  static const settingSearchNoResult = 'ไม่พบเมนูที่ตรงกับคำค้นหา';
  static const clearSearch = 'ล้างคำค้นหา';
  static const lightTheme = 'สว่าง';
  static const darkTheme = 'มืด';
  static const followSystem = 'ตามระบบ';
  static const selectTheme = 'เลือกธีม';
  static const setDisplayTheme = 'ตั้งค่ารูปแบบการแสดงผลของแอป';

  static const invalidUsernameOrPassword = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
  static const offlineLoginSuccess = 'เข้าสู่ระบบ (โหมด Offline)';
  static const offlineLoginPasswordMismatch =
      'ไม่สามารถเชื่อมต่อได้ และรหัสผ่านที่บันทึกไว้ไม่ตรงกัน';
  static const loginError = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
  static const logoutError = 'เกิดข้อผิดพลาดในการออกจากระบบ';
  static const offlineLoginError = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบออฟไลน์';
  static const pinCode = 'รหัส PIN';
  static const newPin = 'รหัส PIN ใหม่';
  static const confirmNewPin = 'ยืนยันรหัส PIN ใหม่';
  static const currentPinOptional = 'PIN ปัจจุบัน (ใช้ตอนปิด PIN)';
  static const currentPinRequiredForChange =
      'PIN ปัจจุบัน (จำเป็นสำหรับเปลี่ยน PIN)';
  static const enablePin = 'เปิดใช้งาน PIN';
  static const changePin = 'เปลี่ยนรหัส PIN';
  static const disablePin = 'ปิดใช้งาน PIN';
  static const pinMustBe6Digits = 'รหัส PIN ต้องเป็นตัวเลข 6 หลัก';
  static const pinMismatch = 'PIN ไม่ตรงกัน';
  static const invalidPin = 'รหัส PIN ไม่ถูกต้อง';
  static const pinSavedSuccess = 'บันทึก PIN เรียบร้อยแล้ว';
  static const pinDisabledSuccess = 'ปิดการใช้งาน PIN แล้ว';
  static const pinSaveFailed = 'ไม่สามารถบันทึก PIN ได้';
  static const enterCurrentPin = 'กรุณากรอก PIN ปัจจุบันให้ครบ 6 หลัก';
  static const invalidCurrentPin = 'PIN ปัจจุบันไม่ถูกต้อง';
  static const pinSecurityTitle = 'ความปลอดภัยด้วย PIN';
  static const pinSecurityDescription =
      'ตั้งค่า PIN 6 หลักเพื่อปลดล็อกระบบหลังจากล็อกอินหรือเปิดแอปครั้งถัดไป';
  static const pinSecurityMenuSubtitle =
      'ตั้งค่า PIN 6 หลักเพื่อปลดล็อกเข้าใช้งาน';
  static const enterPinToContinue = 'กรอกรหัส PIN เพื่อดำเนินการต่อ';
  static const pinUnlockDescription =
      'ยืนยันตัวตนด้วย PIN 6 หลักก่อนเข้าใช้งานระบบ';
  static const forgotPinUsePassword = 'ลืม PIN? เข้าด้วยรหัสผ่าน';
  static const pinTemporarilyLocked = 'PIN ถูกล็อกชั่วคราว กรุณารออีก';
  static const remainingAttempts = 'จำนวนครั้งที่เหลือ';
  static const enableBiometricUnlock = 'เปิดปลดล็อกด้วยไบโอเมตริกซ์';
  static const biometricSupportedHint =
      'ใช้สแกนลายนิ้วมือ/ใบหน้า/Windows Hello เพื่อปลดล็อก';
  static const biometricUnavailableHint =
      'อุปกรณ์นี้ยังไม่รองรับการยืนยันตัวตนแบบไบโอเมตริกซ์';
  static const useBiometricUnlock = 'ใช้ไบโอเมตริกซ์ปลดล็อก';
  static const biometricAuthReason = 'ยืนยันตัวตนเพื่อเข้าสู่ระบบ';
  static const biometricAuthFailed = 'ไม่สามารถยืนยันตัวตนด้วยไบโอเมตริกซ์ได้';
  static const setupPinNowTitle = 'ตั้งค่า PIN ก่อนเข้าใช้งาน';
  static const setupPinNowDescription =
      'เพื่อความปลอดภัย กรุณาตั้งค่า PIN 6 หลักก่อนเข้าใช้งานระบบ';
  static const setupPinNowAction = 'ตั้งค่า PIN';
  static const logoutForNow = 'ออกจากระบบ';
  static const pinSetupSkippedWarningPrefix = 'คุณข้ามการตั้ง PIN มาแล้ว';
  static const timesSuffix = 'ครั้ง';
  static const pinSetupSkipLimitReached =
      'ครบจำนวนการข้ามที่อนุญาตแล้ว กรุณาตั้ง PIN เพื่อเข้าใช้งานต่อ';

  // Home navigation
  static const home = 'หน้าหลัก';
  static const incomeRecord = 'บันทึกรับเงิน';
  static const expenseRecord = 'บันทึกเบิกเงิน';

  /// เมนูหลัก — บันทึกใบสำคัญคู่จ่าย / เบิกจริง (หลังอนุมัติใบขอเบิก)
  static const expenseVoucherRecord = 'เบิกจริง (ใบสำคัญ)';
  static const loanRecord = 'บันทึกยืมเงิน';
  static const approvalRecord = 'อนุมัติการเบิก';
  static const financeReport = 'รายงานการเงิน';
  static const systemSetting = 'ตั้งค่าระบบ';

  // Reset database
  static const resetDbTitle = 'รีเซทฐานข้อมูล';
  static const resetDbSubtitle = 'ล้างข้อมูลทั้งหมดและสร้างใหม่ตั้งต้น';
  static const resetDbTooltip =
      'ลบข้อมูลทั้งหมดและ migrate ข้อมูลตั้งต้นใหม่\nใช้เมื่อต้องการเริ่มต้นระบบใหม่ทั้งหมด';
  static const resetDbConfirmTitle = 'ยืนยันการรีเซท?';
  static const resetDbConfirmMessage =
      'ข้อมูลทั้งหมดในเครื่องจะถูกลบอย่างถาวร\nรวมถึงรายรับ รายจ่าย สมาชิก และการตั้งค่าทั้งหมด\n\nระบบจะสร้างข้อมูลตั้งต้นใหม่อัตโนมัติหลังรีเซท';
  static const resetDbConfirmButton = 'รีเซท';
  static const resetDbSuccess = 'รีเซทฐานข้อมูลเรียบร้อยแล้ว';
  static const resetDbTabLabel = 'รีเซท';
  static const resetDbWarningSectionTitle = 'คำเตือนก่อนรีเซท';
  static const resetDbWarningTitle = 'ดำเนินการนี้ไม่สามารถยกเลิกได้';
  static const resetDbWarningBody =
      'การรีเซทจะลบข้อมูลทั้งหมดในเครื่อง รวมถึง:\n'
      '• รายรับ / รายจ่าย / ยืมเงิน\n'
      '• สมาชิก / ผู้รับ-ผู้จ่าย / ประเภท\n'
      '• ผู้ใช้งาน / สิทธิ์ / แหล่งงบประมาณ\n'
      '• การตั้งค่าทั้งหมด\n\n'
      'แนะนำให้สำรองข้อมูลก่อนดำเนินการ';
  static const resetDbProcessSectionTitle = 'สิ่งที่จะเกิดขึ้นหลังรีเซท';
  static const resetDbStepDeleteFile = 'ลบไฟล์ฐานข้อมูล saccm.db';
  static const resetDbStepMigrateSchema =
      'สร้างตารางและ migrate schema ใหม่ทั้งหมด';
  static const resetDbStepSeedInitialData =
      'เติมข้อมูลตั้งต้น เช่น ผู้ใช้ admin / officer เมนู และประเภทรายรับ';
  static const resetDbStepGoLogin = 'นำทางไปหน้าล็อกอินเพื่อเริ่มต้นใหม่';
  static const resetDbServerNote =
      'ข้อมูลบน server จะไม่ถูกกระทบ ใช้ฟังก์ชัน "นำเข้าจาก Server" เพื่อดึงข้อมูลกลับมาได้';
  static const resetDbActionSectionTitle = 'เริ่มดำเนินการ';
  static const resetDbActionDescription =
      'กดปุ่มด้านล่างเมื่อสำรองข้อมูลเรียบร้อยและต้องการเริ่มต้นฐานข้อมูลในเครื่องใหม่';
  static const resetDbBusy = 'กำลังรีเซท...';
  static const resetDbHelpBackupFirst =
      'สำรองฐานข้อมูลก่อนทุกครั้งหากยังต้องการเก็บข้อมูลปัจจุบันไว้';
  static const resetDbHelpLocalOnly =
      'การรีเซทมีผลกับฐานข้อมูล SQLite ในเครื่องนี้เท่านั้น ไม่ลบข้อมูลบน server กลาง';
  static const resetDbHelpLoginAgain =
      'หลังรีเซท ระบบจะพาไปหน้าล็อกอินเพื่อเริ่มต้นใช้งานจากข้อมูลตั้งต้น';
  static String resetDbError(Object error) => 'เกิดข้อผิดพลาด: $error';

  /// คำอธิบายใต้หัวข้อหน้าตั้งค่าระบบ — ชี้ว่าข้อมูลพื้นฐานโรงเรียนอยู่ในหมวดด้านล่าง
  static const systemSettingsSchoolBasicsHint =
      'เรียงตามลำดับข้อมูลที่ต้องเตรียมก่อนเริ่มใช้งานจริง: ข้อมูลโรงเรียนและผู้ใช้ → ผู้เกี่ยวข้อง → แหล่งเงินและหมวดบัญชี → เอกสาร/ทะเบียน → ตรวจสอบและสำรองข้อมูล';
  static const settingsStepFoundation = 'ขั้นที่ 1: ข้อมูลหลักและความปลอดภัย';
  static const settingsStepPeople = 'ขั้นที่ 2: ผู้ใช้และผู้เกี่ยวข้อง';
  static const settingsStepFinance = 'ขั้นที่ 3: แหล่งเงินและหมวดบัญชี';
  static const settingsStepDocuments = 'ขั้นที่ 4: เอกสารและทะเบียน';
  static const settingsStepMaintenance = 'ขั้นที่ 5: ตรวจสอบและดูแลระบบ';
  static const receiptBookSettingShortcutTitle = 'เล่มใบเสร็จ';
  static const receiptBookSettingShortcutSubtitle =
      'เปิดทะเบียนคุมใบเสร็จเพื่อเพิ่มเล่มและช่วงเลขที่';
  static const partyPayeePayerTitle = 'ผู้รับ/ผู้จ่าย';
  static const partyPayeePayerSubtitle =
      'จัดการรายชื่อคู่สัญญาเพื่อใช้ในรายรับ/รายจ่าย';
  static const partyManagementFilterTooltip = 'ตัวกรอง';
  static const partyManagementAuditTooltip = 'ประวัติแก้ไข';
  static const partyManagementAddAction = 'เพิ่มผู้เกี่ยวข้อง';
  static const partyManagementSearchHint =
      'ค้นหาชื่อ, เลขผู้เสียภาษี, บทบาท หรือเบอร์โทร';
  static const partyManagementEmpty = 'ไม่พบข้อมูล';

  /// ป้ายเมนูออกจากระบบ (sidebar — ฝังในแอป ไม่มาจาก app_menu)
  static const exitProgram = logoutForNow;
  static const confirmExitProgram = 'คุณต้องการออกจากระบบใช่หรือไม่';
  static const confirm = 'ยืนยัน';
  static const menu = 'เมนู';

  /// หน้าตั้งค่าเมนูหลัก (ตาราง app_menu บนเครื่อง)
  static const menuConfigurationTitle = 'ตั้งค่าเมนูหลัก';
  static const menuConfigurationSubtitle =
      'เปลี่ยนชื่อหมวด/รายการ ลำดับ และเปิดหรือปิดการแสดง — บันทึกลงเครื่องก่อน แล้วอัปโหลดเซิร์ฟเวอร์เมื่อออนไลน์';

  /// หน้าตั้งค่ารูปแบบเลขเอกสาร (doc_group)
  static const docGroupSettingsTitle = 'ตั้งค่ารูปแบบเลขเอกสาร';
  static const docGroupSettingsSubtitle =
      'กำหนดรหัสนำหน้าและรูปแบบเลขรัน เช่น INC-20260521-0001 หรือ 001';
  static const docGroupSettingsAdminOnly =
      'เฉพาะผู้ดูแลระบบเท่านั้นที่ตั้งค่ารูปแบบเลขเอกสารได้';
  static const docGroupTableName = 'ตาราง';
  static const docGroupName = 'ชื่อรูปแบบ';
  static const docGroupRunGroup = 'รหัสนำหน้า';
  static const docGroupRunGroupHint =
      'ใส่รหัสสั้นไม่เว้นวรรค เช่น INC, REQ, RB หรือ บร. และต้องไม่ซ้ำกับรูปแบบอื่น';
  static const docGroupRunGroupRequired = 'กรุณาระบุรหัสนำหน้า';
  static const docGroupRunGroupInvalid = 'รหัสนำหน้าห้ามมีช่องว่าง';
  static const docGroupRunGroupDuplicate =
      'รหัสนำหน้านี้มีอยู่แล้วในรูปแบบอื่น';
  static const docGroupFormat = 'รูปแบบเลข';
  static const docGroupFormatHint =
      'ใส่ข้อความคงที่ร่วมกับตัวแปร เช่น {RUNGROUP}-{YYYY}{MM}{DD}-{RUN4} หรือ {RUN3}';
  static const docGroupFormatGuide =
      'ตัวแปรที่ใช้ได้: {RUNGROUP}/{RG}=รหัสนำหน้า, {YYYY}/{YY}=ปี, {FY}=ปีงบประมาณ พ.ศ., {MM}=เดือน, {DD}=วัน, {RUN}/{RUN3}/{RUN4}=เลขรันตามจำนวนหลัก';
  static const docGroupFormatRequiredRun =
      'รูปแบบต้องมี {RUN} หรือ {RUN3} เพื่อรันเลขอัตโนมัติ';
  static const docGroupEditTitle = 'แก้ไขรูปแบบเลขเอกสาร';
  static const docGroupSaveSuccess = 'บันทึกรูปแบบเลขเอกสารเรียบร้อย';
  static const docGroupEmpty = 'ยังไม่มีรูปแบบเลขเอกสาร';
  static const menuConfigurationSlugHint = 'รหัสภายใน (อ่านอย่างเดียว)';
  static const menuConfigurationDisplayName = 'ชื่อที่แสดงในเมนู';
  static const menuConfigurationSyncFromServer = 'ดึงจากเซิร์ฟเวอร์';
  static const menuConfigurationSave = 'บันทึก';
  static const menuConfigurationSectionHeader = 'หมวด';
  static const menuConfigurationLeafHeader = 'รายการเมนู';
  static const menuConfigurationMoveUp = 'ขึ้น';
  static const menuConfigurationMoveDown = 'ลง';
  static const menuConfigurationActive = 'แสดงในเมนู';
  static const menuConfigurationServerSyncFailed =
      'บันทึกในเครื่องแล้ว แต่อัปโหลดเซิร์ฟเวอร์ไม่สำเร็จ — ลองอีกครั้งเมื่อออนไลน์';
  static const menuConfigurationNeedLogin =
      'ต้องล็อกอินแบบเชื่อมต่อเซิร์ฟเวอร์เพื่อดึงหรืออัปโหลดเมนู';
  static const menuConfigurationNoPermission = 'คุณไม่มีสิทธิ์แก้ไขเมนู';

  // Usage flow helper (คู่มือขั้นตอนการใช้งานหลัก)
  static const usageFlowHelperTitle = 'คู่มือขั้นตอนการใช้งาน';

  /// ชื่อสั้นในเมนู sidebar / bottom nav
  static const usageFlowHelperNavLabel = 'คู่มือใช้งาน';
  static const usageFlowHelperIntro =
      'ลำดับงานแนะนำของระบบ SACCM ตั้งแต่เข้าใช้งานจนถึงรายงาน — สลับหน้าผ่านเมนูด้านซ้าย (จอกว้าง) หรือแถบล่าง (จอแคบ) และปุ่มเมนู (มุมซ้ายบน) เมนู “หน้าหลัก” “ตั้งค่าระบบ” และ “ออกจากระบบ” อยู่คงที่ในแอป ส่วนรายการอื่น (เช่น คู่มือใช้งาน อนุมัติ ธุรกรรม) โหลดจากตาราง app_menu ในเครื่องและแสดงตามสิทธิ์ของกลุ่มผู้ใช้ — ลำดับหมวดบน UI อาจต่างจากคู่มือนี้ได้หากผู้ดูแลปรับข้อมูลเมนูหรือสิทธิ์ — แตะแท็บ “แผนภาพ” ด้านบนเพื่อดูภาพรวมการทำงานแบบไดอะแกรม';
  static const startupReadinessTabLabel = 'เริ่มต้นใช้งาน';
  static const startupReadinessTitle = 'เช็กลิสต์ข้อมูลก่อนเริ่มใช้งาน';
  static const startupReadinessIntro =
      'ตรวจข้อมูลที่ควรมีในเครื่องก่อนเริ่มบันทึกรับ-จ่ายจริง รายการที่ยังไม่พร้อมสามารถกดไปเพิ่มหรือแก้ไขที่หน้าที่เกี่ยวข้องได้ทันที';
  static const startupReadinessLoading = 'กำลังตรวจข้อมูลเริ่มต้น...';
  static const startupReadinessEmptyAction = 'ตรวจอีกครั้ง';
  static const startupReadinessReady = 'พร้อม';
  static const startupReadinessAttention = 'ควรตรวจสอบ';
  static const startupReadinessMissing = 'ยังขาด';
  static const startupReadinessOpenPage = 'ไปเพิ่มข้อมูล';
  static const startupReadinessReviewPage = 'ไปตรวจสอบ';
  static const startupReadinessNoPageAccess =
      'ไม่มีลิงก์ไปหน้านี้จากคู่มือในสิทธิ์ปัจจุบัน';
  static const startupReadinessRequiredSection = 'ข้อมูลหลักที่ต้องตั้งค่า';
  static const startupReadinessFinanceSection = 'ข้อมูลการเงินและทะเบียน';
  static const startupReadinessPeopleSection = 'ผู้ใช้งานและผู้เกี่ยวข้อง';
  static const startupReadinessOperationSection = 'การใช้งานต่อเนื่อง';
  static const cashKeepingLimitTitle = 'วงเงินเก็บรักษา';
  static String startupReadinessSummary({
    required int ready,
    required int total,
    required int needsWork,
  }) =>
      'พร้อมแล้ว $ready/$total รายการ • ต้องจัดการ $needsWork รายการ';
  static String startupReadinessFiscalYear(String fiscalYear) =>
      'ปีงบประมาณปัจจุบัน $fiscalYear';
  static String startupReadinessCount(String label, int count) =>
      '$label: $count รายการ';
  static String startupReadinessAmount(String label, String amount) =>
      '$label: $amount บาท';
  static const startupSchoolProfileDesc =
      'ชื่อ ที่อยู่ และข้อมูลติดต่อของโรงเรียน ใช้บนหน้าหลัก รายงาน และไฟล์ส่งออก';
  static const startupUsersDesc =
      'บัญชีผู้ใช้ กลุ่มสิทธิ์ และผู้อนุมัติ เพื่อให้การบันทึกและตรวจสอบแยกตามบทบาท';
  static const startupBudgetSourceDesc =
      'แหล่งเงินประจำปีงบประมาณและยอดงบ ใช้เลือกในรายรับ รายจ่าย และรายงานคงเหลือ';
  static const startupIncomeTypeDesc =
      'หมวดรายรับและหมวด OB สำหรับแยกทะเบียนคุม รวมถึงการผูกแหล่งเงินให้เลือกได้ในฟอร์มรับเงิน';
  static const startupExpenseTypeDesc =
      'ประเภทรายจ่ายสำหรับฟอร์มเบิกจ่ายและรายงานรับ-จ่ายประจำปี';
  static const startupMoneyChannelDesc =
      'วิธีรับ-จ่ายเงิน เช่น เงินสด โอน เช็ค และเงินฝากส่วนราชการผู้เบิก';
  static const startupChequeAccountDesc =
      'บัญชีเช็คและบัญชีธนาคารที่เกี่ยวข้อง ใช้กับการจ่ายเช็คและการตรวจสอบเงินฝากธนาคาร';
  static const startupPartyDesc =
      'ผู้จ่าย ผู้รับเงิน ร้านค้า บริษัท ผู้รับจ้าง และผู้เกี่ยวข้องที่ใช้ในเอกสารรับ-จ่าย';
  static const startupMemberDesc =
      'สมาชิกหรือบุคลากรที่ใช้กับใบขอเบิก สัญญายืมเงิน และข้อมูลผู้รับผิดชอบ';
  static const startupReceiptBookDesc =
      'เล่มใบเสร็จและช่วงเลขที่ เพื่อออกใบเสร็จจากรายการรับเงิน';
  static const startupDocGroupDesc =
      'รูปแบบเลขเอกสารอัตโนมัติ เช่น รายรับ ใบขอเบิก ใบยืม และเล่มใบเสร็จ';
  static const startupOpeningBalanceDesc =
      'ยอดยกมาต้นปีงบประมาณ แยกเงินสด ธนาคาร และส่วนราชการผู้เบิก';
  static const startupCashLimitDesc =
      'วงเงินเก็บรักษาเงินสดและเงินฝากตามประเภทเงิน ใช้เตือนก่อนปิดวัน';
  static const startupAppointmentDesc =
      'คำสั่งแต่งตั้งกรรมการหรือเจ้าหน้าที่ที่เกี่ยวข้องกับการเก็บรักษาเงิน';
  static const startupBackupDesc =
      'สำรองฐานข้อมูลก่อนเริ่มใช้งานจริง อัปเดตแอป หรือย้ายเครื่อง';
  static const startupSchoolProfileMissingDetail =
      'ยังไม่พบชื่อและที่อยู่โรงเรียน';
  static const startupSchoolProfileReadyDetail = 'ตั้งค่าข้อมูลโรงเรียนแล้ว';
  static const startupBudgetSourceZeroAmountDetail =
      'มีแหล่งเงินแล้ว แต่ยอดงบและยอดยกมายังเป็น 0';
  static const startupIncomeTypeLinkMissingDetail =
      'มีหมวดรายรับแล้ว แต่ยังไม่พบการผูกหมวดกับแหล่งเงิน';
  static const startupOpeningBalanceOptionalDetail =
      'ถ้าเริ่มใช้กลางปีหรือมียอดคงเหลือเดิม ให้บันทึกยอดยกมา';
  static const startupBackupManualDetail =
      'ควรสำรองหลังตั้งค่าข้อมูลเริ่มต้นครบ';
  static const usageFlowS1Title = '1. เข้าสู่ระบบและความปลอดภัย';
  static const usageFlowS1_1 =
      'เข้าสู่ระบบด้วยชื่อผู้ใช้และรหัสผ่าน หากเข้าไม่ได้ให้ติดต่อผู้ดูแลระบบ';
  static const usageFlowS1_2 =
      'เมื่อระบบสั่งให้ทำ ให้เปลี่ยนรหัสผ่านเริ่มต้น ตั้ง PIN หรือใช้ไบโอเมตริกซ์ตามขั้นตอนบนหน้าจอ';
  static const usageFlowS1_3 =
      'ผู้ดูแลที่ติดตั้งเซิร์ฟเวอร์ใหม่ให้เตรียมการเชื่อมต่อฐานข้อมูลและตรวจสอบ API ให้พร้อมก่อนให้ผู้ใช้ล็อกอิน';
  static const usageFlowS1_4 =
      'เมื่อใช้งานเสร็จ ใช้เมนู “ออกจากระบบ” เพื่อยกเลิกสถานะล็อกอินและกลับไปหน้าเข้าสู่ระบบ (แอปยังเปิดอยู่)';
  static const usageFlowS2Title = '2. ตั้งค่าข้อมูลพื้นฐาน (ก่อนบันทึกรายการ)';
  static const usageFlowS2_1 =
      'เปิดเมนู “ตั้งค่าระบบ” แล้วในหมวดทั่วไปตั้ง “ข้อมูลโรงเรียน” (ชื่อ ที่ตั้ง ฯลฯ) จากนั้นจัดการคำนำหน้า หมวดรายรับ บัญชี/แหล่งเงิน แหล่งงบประมาณ (ถ้ามีสิทธิ์) และผู้รับ/ผู้จ่ายให้พร้อมใช้งาน — การตั้งค่าแหล่งเงินสามารถเว้นหมวดรายรับได้ และที่หน้ารายชื่อผู้รับ/ผู้จ่ายมีแก้ไข สลับใช้งาน และลบได้ (รายการรับ/จ่ายเดิมจะคงชื่อในบันทึก แต่จะไม่ชี้ผู้เกี่ยวข้องที่ลบแล้ว)';
  static const usageFlowS2_2 =
      'ตั้งค่าสมาชิกและบัญชีผู้ใช้ (ผู้ดูแล) เพื่อให้การอนุมัติและการทำงานร่วมกันถูกต้องตามบทบาท';
  static const usageFlowS2_3 =
      'ตรวจค่าเริ่มต้นของระบบจากหน้า “ค่าเริ่มต้น” เพื่อเข้าถึง “การเชื่อมต่อระบบ” “ธีมแอป” “เพิ่มหมวดรายรับ” และ “ตั้งค่ารูปแบบเลขเอกสาร” สำหรับผู้ดูแล รวมถึงตรวจ PIN และสุขภาพฐานข้อมูลเมื่อจำเป็น';
  static const usageFlowS2_4 =
      'รายการเมนูที่ปรับได้ (ชื่อแท็บ หมวด และลำดับ) บันทึกในตาราง app_menu บนเครื่อง (parent_id = กลุ่ม/ซับเมนู) — “หน้าหลัก” “ตั้งค่าระบบ” และ “ออกจากระบบ” ไม่เก็บในตารางนี้ การเห็นแต่ละรายการผูกกับสิทธิ์ (เช่น nav.* / อนุมัติ / ตั้งค่า) ตามกลุ่มผู้ใช้ — จัดการสิทธิ์ได้ที่ “ผู้ใช้ระบบ” เมื่อมีสิทธิ์';
  static const usageFlowS2_5 =
      'ผู้มีสิทธิ์ “ตั้งค่าเมนูหลัก” ปรับชื่อ ลำดับ และเปิด/ปิดรายการในเมนูได้ที่ ตั้งค่าระบบ → ตั้งค่าเมนูหลัก — แตะปุ่มด้านล่างได้ถ้ามีสิทธิ์';
  static const usageFlowS3Title = '3. ภาพรวมและธุรกรรมประจำวัน';
  static const usageFlowS3_1 =
      'หน้า “หน้าหลัก” แสดงสรุปรายรับ รายจ่าย และกราฟช่วยดูภาพรวมยอดเงิน — ถ้าตั้ง “ข้อมูลโรงเรียน” ไว้ ชื่อโรงเรียนจะแสดงในส่วนหัวภาพรวม';
  static const usageFlowS3_2 =
      'ใช้ “บันทึกรับเงิน” เพื่อลงรายการเงินเข้า พร้อมหมวดรายรับและวิธีรับเงิน — ช่อง “รับจาก” เลือกได้เฉพาะผู้จ่าย (หรือทั้งสองฝั่ง) ที่ลงทะเบียนและใช้งานเท่านั้น';
  static const usageFlowS3_3 =
      'ใช้เมนู “ใบขอเบิก” (กลุ่ม ธุรกรรมรับ-จ่าย) เพื่อสร้างคำขอเบิก — เมื่อบันทึกแล้วระบบจะตั้งสถานะรออนุมัติอัตโนมัติ';
  static const usageFlowS3_3b =
      'หลังอนุมัติแล้ว ใช้เมนู “เบิกจริง (ใบสำคัญ)” เพื่อบันทึกรายการเบิกจ่ายจริง — เลือกแหล่งงบ กรอกยอดและรายละเอียด ช่อง “จ่ายให้” เลือกได้เฉพาะผู้รับที่ลงทะเบียนและใช้งาน (คล้ายช่อง “รับจาก” ในรายรับ)';
  static const usageFlowTransactionShortcutsTitle = 'เปิดเมนูธุรกรรมจากที่นี่';
  static const usageFlowTransactionShortcutsHint =
      'แตะเพื่อไป “บันทึกรับเงิน” “ใบขอเบิก” “เบิกจริง (ใบสำคัญ)” หรือ “บันทึกยืมเงิน/คืนเงินยืม” (ถ้าเมนูถูกปิดหรือไม่มีสิทธิ์ ระบบจะแจ้ง)';
  static const usageFlowLoanShortcutTitle = 'บันทึกยืมเงิน/คืนเงินยืม';
  static const usageFlowS3_4 =
      'ใช้ “บันทึกยืมเงิน” เพื่อกรอกหัวสัญญาในตาราง loan และแยกยอดตามหมวดรายรับใน loan_sub (ยอด amount บน loan = ผลรวมแถวย่อย) พร้อมยอดยกมา opening_outstanding ถ้ามี; เมื่อต้อง “คืนเงินยืม” ให้เปิดเมนูคืนเงินยืมแล้วเลือกเลขที่ใบยืมจากรายการในฐานข้อมูล จากนั้นกรอกยอดคืนไม่เกินคงเหลือ';
  static const usageFlowS4Title = '4. การอนุมัติและรายงาน';
  static const usageFlowS4_1 =
      'เมนู “อนุมัติการเบิก” แสดงเฉพาะผู้มีสิทธิ์ — ใช้ตรวจและอนุมัติ/ปฏิเสธคำขอเบิก';
  static const usageFlowS4_2 =
      'เมนู “รายงานการเงิน” ใช้สรุปและส่งออกข้อมูลตามช่วงเวลาและเงื่อนไขที่ต้องการ — ถ้าตั้ง “ข้อมูลโรงเรียน” ไว้ ชื่อโรงเรียนจะแสดงในหัวหน้ารายงานและบรรทัดอธิบายตอนต้นของไฟล์ CSV แหล่งงบเมื่อส่งออก';
  static const usageFlowS4_3 =
      'แท็บ “เงินคงเหลือประจำวัน” / “งบเทียบยอดธนาคาร” ในรายงาน ใช้ตรวจยอดสามช่อง (เงินสด เงินฝากธนาคาร เงินฝากส่วนราชการ) และเทียบกับ Statement ธนาคารตามคู่มือสถานศึกษา';
  static const usageFlowS4_4 =
      'สิทธิ์อนุมัติแยกเป็นสามระดับ: ดูรายการ อนุมัติ และปฏิเสธ — ผู้ใช้อาจมีเพียงบางสิทธิ์ ระบบจะแสดงปุ่มและแถบแจ้งด้านบนหน้าอนุมัติตามสิทธิ์ — ให้ผู้ดูแลกำหนดที่ “ผู้ใช้ระบบ” แล้วแตะ “สิทธิ์กลุ่ม”';
  static const usageFlowApprovalShortcutTitle = 'ไปหน้าอนุมัติการเบิก';
  static const usageFlowApprovalShortcutSubtitle =
      'เปิดแท็บ Workflow อนุมัติ (ถ้าเมนูถูกปิดหรือไม่มีสิทธิ์ ระบบจะแจ้ง)';
  static const usageFlowFormsShortcutTitle = 'ไปหน้าแบบฟอร์มเอกสาร';
  static const usageFlowFormsShortcutSubtitle =
      'เลือกเครื่องพิมพ์และพิมพ์ PDF จากแบบฟอร์ม (ถ้าเมนูถูกปิดหรือไม่มีสิทธิ์ ระบบจะแจ้ง)';
  static const usageFlowS5Title = '5. ทะเบียนคุมและแบบฟอร์ม';
  static const usageFlowS5_0 =
      'เมนู “ทะเบียนคุม” รวม 10 แท็บตามคู่มือ: เงินนอกงบประมาณ 13 หมวด, หลักฐานขอเบิก, ใบสำคัญคู่จ่าย, การจ่ายเช็ค, สัญญายืมเงิน, ใบเสร็จรับเงิน, เงินประกันสัญญา/ภาษีหัก ณ ที่จ่าย, เงินฝากธนาคารประเภทกระแสรายวัน (หน้า 36), สมุดคู่ฝากส่วนราชการผู้เบิก (หน้า 43), และรับ-นำส่งเงินรายได้แผ่นดิน (หน้า 44) — ดูสรุปรายเดือน + ยอดยกมา/ยกไป ตามรูปแบบของคู่มือ';
  static const usageFlowS5_00 =
      'เมนู “แบบฟอร์มเอกสาร” สร้าง PDF แล้วเปิดหน้าต่างเลือกเครื่องพิมพ์ทันที: ใบรับรองแทนใบเสร็จ (บก.111), ใบสำคัญรับเงิน, หนังสือรับรองภาษีหัก ณ ที่จ่าย, ใบแนบใบเสร็จ — กรอกข้อมูลในหน้าจอแล้วสั่งพิมพ์ได้เลย';
  static const usageFlowS5_01 =
      'เลขที่เอกสารสร้างอัตโนมัติจากเซิร์ฟเวอร์ ผู้มีสิทธิ์ “แก้ไขเลขเอกสารด้วยตนเอง” เท่านั้นที่แก้เลขเองได้ — เลือกผู้จัดทำหรือผู้ลงนามจากรายชื่อผู้ใช้ในเครื่องได้เมื่อมีข้อมูลในตารางผู้ใช้';
  static const usageFlowS6Title = '6. การทำงานแบบออฟไลน์และซิงก์';
  static const usageFlowS5_1 =
      'ดูสถานะเครือข่ายจากมุมขวาบน — ออฟไลน์: บันทึกลงเครื่องได้ก่อน เซิร์ฟเวอร์: จะส่งข้อมูลขึ้นเมื่อเชื่อมต่อได้';
  static const usageFlowS5_2 =
      'ถ้ามี “รอส่งเซิร์ฟเวอร์” แสดงว่ามีคิวจากเครื่องที่ยังไม่ขึ้นเซิร์ฟเวอร์ — แตะเพื่อเปิดรายการหรือส่งทันทีได้';
  static const usageFlowS5_3 =
      'สำรองหรือกู้คืนฐานข้อมูลในเครื่องได้ที่ ตั้งค่าระบบ → สำรองและกู้คืน (แยกแท็บ Backup / Restore) — ไฟล์สำรองบันทึกลงโฟลเดอร์ดาวน์โหลดของระบบอัตโนมัติ; เมื่อออนไลน์และล็อกอินเซิร์ฟเวอร์ ระบบจะส่งคิว ดึงข้อมูลที่ซิงก์กับเซิร์ฟเวอร์ลงเครื่องใหม่ (ธุรกรรม งบ ผู้เกี่ยวข้อง ผู้ใช้ และตารางย่อยที่เกี่ยวข้อง) แล้วเทียบจำนวนแถวหลายตารางก่อนสำรอง; ออฟไลน์หรือโหมด local จะสำรองจากไฟล์ในเครื่องได้ทันที';
  static const usageFlowS5_4 =
      'หลังซิงก์หรือกู้คืนข้อมูล ให้กลับมาตรวจหน้าหลัก รายงาน และทะเบียนคุมที่เกี่ยวข้องอีกครั้ง เพื่อยืนยันยอดและรายการล่าสุดก่อนใช้งานต่อ';

  // สำรอง / กู้คืน SQLite
  static const backupRestoreTitle = 'สำรองและกู้คืน';
  static const databaseMaintenanceTitle = 'จัดการฐานข้อมูล';
  static const databaseMaintenanceSubtitle =
      'สำรอง กู้คืน และรีเซทฐานข้อมูล SQLite ในเครื่อง';
  static const databaseMaintenanceTooltip =
      'สำรองข้อมูล กู้คืนไฟล์ หรือรีเซทฐานข้อมูลในเครื่อง\nควรสำรองก่อนรีเซทหรืออัปเดตแอป';
  static const backupTabLabel = 'สำรองข้อมูล';
  static const restoreTabLabel = 'กู้คืนข้อมูล';
  static const backupRestoreIntro =
      'สำรองสร้างไฟล์ .db ลงโฟลเดอร์ดาวน์โหลดของระบบโดยอัตโนมัติ (ถ้าไม่มีจะใช้โฟลเดอร์เอกสารของแอป) ไม่ให้เลือกตำแหน่งเอง — การกู้คืนจะแทนที่ฐานข้อมูลเมื่อเปิดแอปรอบถัดไปหลังยืนยัน แนะนำสำรองก่อนอัปเดตแอปหรือย้ายเครื่อง';
  static const backupSectionOnline = 'เมื่อเชื่อมต่อเซิร์ฟเวอร์ได้';
  static const backupPrecheckDescription =
      'ส่งคิวที่ค้างแล้วดึงข้อมูลที่ซิงก์กับเซิร์ฟเวอร์ลงเครื่องใหม่ทั้งก้อน (ธุรกรรม งบ ผู้เกี่ยวข้อง ผู้ใช้ สมาชิก บัญชีธนาคาร/เช็ค เช็คจ่าย และตารางย่อยที่เกี่ยวข้อง) จากนั้นเทียบจำนวนแถวกับฐานข้อมูลบนเซิร์ฟเวอร์';
  static const backupPrecheckButton = 'ตรวจสอบความตรงกับเซิร์ฟเวอร์';
  static const backupPrecheckOfflineHint =
      'ขณะนี้เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ — ใช้การสำรองจากเครื่องด้านล่างได้';
  static const backupPrecheckLocalTokenHint =
      'ล็อกอินแบบในเครื่อง (ไม่มี JWT เซิร์ฟเวอร์) — ข้ามการเทียบกับเซิร์ฟเวอร์ ใช้สำรองจากเครื่องได้';
  static const backupPrecheckAligned =
      'จำนวนแถวหลักตรงกับเซิร์ฟเวอร์แล้ว — กดสำรองแบบตรวจเซิร์ฟเวอร์ได้';
  static String backupPrecheckMismatch(String tables) =>
      'จำนวนแถวไม่ตรงกับเซิร์ฟเวอร์ที่ตาราง: $tables — ลองกดตรวจสอบอีกครั้งหรือสำรองจากเครื่องถ้าต้องการด่วน';
  static const backupExportWithServerCheck =
      'สำรองไฟล์ (ตรวจกับเซิร์ฟเวอร์ก่อน)';
  static const backupSectionOffline = 'สำรองจากเครื่องเท่านั้น';
  static const backupLocalOnlyDescription =
      'เมื่อออฟไลน์ ล็อกอินแบบ local หรือต้องการสำเนาทันทีโดยไม่บังคับให้ตรงกับเซิร์ฟเวอร์';
  static const backupExportLocalOnly = 'สำรองไฟล์ (จากเครื่องเท่านั้น)';
  static const backupSavedTo = 'บันทึกสำรองแล้วที่';
  static const backupUnsupportedWeb =
      'การสำรอง/กู้คืนแบบไฟล์ยังไม่รองรับบนเว็บ';
  static const backupRestoreSection = 'กู้คืนจากไฟล์สำรอง';
  static const backupRestorePickHint =
      'เลือกไฟล์ .db ที่สำรองจากแอปนี้ จากนั้นปิดแอปแล้วเปิดใหม่เพื่อให้การกู้คืนสมบูรณ์';
  static const backupRestorePickButton = 'เลือกไฟล์สำรอง (.db)';
  static const backupRestoreInvalidFile =
      'ไฟล์ไม่ใช่ฐานข้อมูล SACCM หรืออ่านไม่ได้';
  static const backupRestoreConfirmTitle = 'ยืนยันการกู้คืน';
  static const backupRestoreConfirmBody =
      'ข้อมูลในเครื่องจะถูกแทนที่เมื่อเปิดแอปรอบถัดไป แน่ใจหรือไม่?';
  static const backupRestoreScheduledTitle = 'ตั้งเวลากู้คืนแล้ว';
  static const backupRestoreScheduledBody =
      'กรุณาปิดแอปให้หมดแล้วเปิดใหม่ — ระบบจะแทนที่ฐานข้อมูลจากไฟล์ที่เลือก';
  static String backupPendingQueueNotEmpty(int n) =>
      'ยังมีข้อมูลรอส่งเซิร์ฟเวอร์ $n รายการ — ตรวจสอบเครือข่ายหรือลองอีกครั้งก่อนสำรองแบบเทียบเซิร์ฟเวอร์';
  static String backupUnsyncedLocalRows(String tables) =>
      'ยังมีข้อมูลในเครื่องที่ยังไม่ส่งเซิร์ฟเวอร์ ($tables) — ระบบหยุดดึงข้อมูลเต็มชุดเพื่อป้องกันข้อมูลถูกทับ';

  /// แท็บในหน้าคู่มือ — รายการขั้นตอนแบบข้อความ
  static const usageFlowTabSteps = 'ขั้นตอน';

  /// แท็บในหน้าคู่มือ — แผนภาพลำดับการทำงาน
  static const usageFlowTabDiagram = 'แผนภาพ';
  static const usageFlowDiagramIntro =
      'ภาพรวมลำดับงานหลัก: ตั้งค่าก่อนบันทึก แล้วใช้หน้าหลักกับเมนูธุรกรรม จากนั้นตรวจอนุมัติและรายงาน — ข้อมูลบันทึกในเครื่องก่อนแล้วซิงก์เมื่อออนไลน์ ลากเพื่อเลื่อน บีบนิ้วเพื่อซูมแผนภาพได้';
  static const usageFlowDiagramBranchLabel =
      'ธุรกรรมประจำวัน (เลือกเมนูที่เกี่ยวข้อง)';
  static const usageFlowDiagramNodeLogin = 'เข้าสู่ระบบ / ความปลอดภัย';
  static const usageFlowDiagramNodeSetup = 'ตั้งค่าข้อมูลพื้นฐาน';
  static const usageFlowDiagramNodeDashboard = 'หน้าหลัก (ภาพรวม)';
  static const usageFlowDiagramNodeIncome = 'รับเงิน';
  static const usageFlowDiagramNodeExpenseReq = 'ใบขอเบิก';
  static const usageFlowDiagramNodeExpense = 'เบิกจริง (ใบสำคัญ)';
  static const usageFlowDiagramNodeLoan = 'ยืมเงิน';
  static const usageFlowDiagramNodeApproval = 'อนุมัติการเบิก';
  static const usageFlowDiagramNodeReports = 'รายงานการเงิน';
  static const usageFlowDiagramNodeSync = 'ออฟไลน์ & ซิงก์ข้อมูล';
  static const usageFlowDiagramTapHint = 'แตะเพื่อเปิดเมนู';
  static const usageFlowNavigateDenied =
      'ไม่สามารถเปิดเมนูนี้ได้ — อาจไม่มีสิทธิ์หรือเมนูถูกปิดในกลุ่มของคุณ';

  // Member/User shared forms
  static const code = 'รหัส';
  static const codeRequired = 'รหัสไม่ควรเป็นค่าว่าง';
  static const prefix = 'คำนำหน้า';
  static const prefixManagementTitle = 'จัดการคำนำหน้า';
  static const prefixManagementSubtitle =
      'เพิ่ม แก้ไข หรือลบคำนำหน้าที่ใช้ในฟอร์มสมาชิกและผู้ใช้ระบบ';
  static const prefixManagementTooltip =
      'ตั้งค่าคำนำหน้า เช่น นาย นาง นางสาว\nใช้กับช่องคำนำหน้าในหน้าสมาชิกและผู้ใช้ระบบ';
  static const prefixSearchHint = 'ค้นหาคำนำหน้า';
  static const prefixEmpty = 'ยังไม่มีคำนำหน้า';
  static const prefixNoResult = 'ไม่พบคำนำหน้าที่ค้นหา';
  static const prefixLoadingBusy = 'กำลังโหลดคำนำหน้า...';
  static const prefixSavingBusy = 'กำลังบันทึกคำนำหน้า...';
  static const prefixDeletingBusy = 'กำลังลบคำนำหน้า...';
  static const prefixAddTitle = 'เพิ่มคำนำหน้า';
  static const prefixEditTitle = 'แก้ไขคำนำหน้า';
  static const prefixName = 'คำนำหน้า';
  static const prefixNameHint = 'เช่น นาย, นาง, นางสาว';
  static const prefixNameRequired = 'คำนำหน้าต้องไม่เป็นค่าว่าง';
  static const prefixDuplicate = 'คำนำหน้านี้มีอยู่แล้ว';
  static const prefixNoDataDialogTitle = 'ยังไม่มีคำนำหน้า';
  static const prefixNoDataDialogBody =
      'เพิ่มคำนำหน้าได้ที่ เมนู “ตั้งค่าระบบ” → “จัดการคำนำหน้า” จากนั้นกลับมาเลือกคำนำหน้าอีกครั้ง';
  static const prefixGoManage = 'ไปจัดการคำนำหน้า';
  static String prefixDeleteConfirmQuestion(String name) =>
      'ต้องการลบคำนำหน้า “$name” หรือไม่?';
  static String prefixUsageCount(int count) => 'ผู้ใช้ที่อ้างอิง $count รายการ';
  static const firstName = 'ชื่อ';
  static const firstNameRequired = 'ชื่อไม่ควรเป็นค่าว่าง';
  static const lastName = 'นามสกุล';
  static const lastNameRequired = 'นามสกุลไม่ควรเป็นค่าว่าง';
  static const email = 'อีเมล์';
  static const contactNumber = 'เบอร์ติดต่อ';
  static const address = 'ที่อยู่';
  static const saveFailed = 'บันทึกข้อมูลไม่สำเร็จ';
  static const saveSuccess = 'บันทึกข้อมูลสำเร็จ';
  static const editSuccess = 'แก้ไขข้อมูลสำเร็จ';
  static const memberListTapToEdit = 'รายการสมาชิก (แตะเพื่อแก้ไข)';
  static const memberSearchHint = 'ค้นหารหัส/ชื่อ/เบอร์';
  static const emptyMember = 'ยังไม่มีข้อมูลสมาชิก';

  // User
  static const addSystemUser = 'เพิ่มผู้ใช้ระบบ';
  static const editSystemUser = 'แก้ไขผู้ใช้ระบบ';
  static const userProfileSection = 'ข้อมูลผู้ใช้';
  static const userLoginSection = 'ข้อมูลเข้าระบบ';
  static const userFormHint =
      'สร้างบัญชีสำหรับเข้าใช้งานบนเครื่องนี้ เลือกกลุ่มผู้ใช้ให้ตรงกับหน้าที่เพื่อกำหนดสิทธิ์เริ่มต้น';
  static const userRequiredBeforeSaveHint =
      'กรอกรหัส คำนำหน้า ชื่อ นามสกุล ชื่อผู้ใช้ รหัสผ่าน และกลุ่มผู้ใช้ให้ครบก่อนบันทึก';
  static const userReadyToSave = 'ข้อมูลผู้ใช้พร้อมบันทึก';
  static const userGroup = 'กลุ่มผู้ใช้';
  static const selectPrefix = 'เลือกคำนำหน้า';
  static const selectUserGroup = 'เลือกกลุ่มผู้ใช้';
  static const noUserGroupAvailable = 'ยังไม่มีกลุ่มผู้ใช้ในระบบ';
  static const duplicateUsername = 'ชื่อผู้ใช้นี้มีอยู่ในระบบแล้ว';
  static const userAdminGroupPermissions = 'สิทธิ์กลุ่ม';
  static const userAdminAccountListSection = 'บัญชีผู้ใช้ในระบบ';
  static const userAdminSearchHint =
      'ค้นหาชื่อผู้ใช้ ชื่อ-นามสกุล อีเมล์ หรือกลุ่มผู้ใช้';
  static const userAdminEmpty = 'ยังไม่มีผู้ใช้ระบบ';
  static const userAdminNoResult = 'ไม่พบผู้ใช้ที่ค้นหา';
  static const userAdminActiveStatus = 'เปิดใช้งาน';
  static const userAdminInactiveStatus = 'ปิดการใช้งาน';
  static const userAdminForcePasswordChange = 'ต้องเปลี่ยนรหัสผ่าน';
  static const userAdminActionsTooltip = 'จัดการผู้ใช้';
  static const userAdminGroupPermissionsSaved = 'บันทึกสิทธิ์กลุ่มแล้ว';
  static const userAdminPermissionCategoryMainMenu = 'เมนูหลัก';
  static const userAdminPermissionCategoryApproval = 'การอนุมัติ';
  static const userAdminPermissionCategoryBudgetSource = 'แหล่งเงิน';
  static const userAdminPermissionCategoryIncome = 'บันทึกรับเงิน';
  static const userAdminPermissionCategoryForms = 'แบบฟอร์มเอกสาร';
  static const userAdminPermissionCategorySettings = 'ตั้งค่าระบบ';
  static const userAdminPermissionCategoryUsers = 'ผู้ใช้และสิทธิ์';
  static const userAdminPermissionNavHome = 'เมนู - หน้าหลัก';
  static const userAdminPermissionNavIncome = 'เมนู - บันทึกรับเงิน';
  static const userAdminPermissionNavExpenseReq = 'เมนู - ใบขอเบิก';
  static const userAdminPermissionNavExpense = 'เมนู - เบิกจริง (ใบสำคัญ)';
  static const userAdminPermissionNavLoan = 'เมนู - บันทึกยืมเงิน';
  static const userAdminPermissionNavReports = 'เมนู - รายงานการเงิน';
  static const userAdminPermissionNavUsageGuide = 'เมนู - คู่มือใช้งาน';
  static const userAdminPermissionNavLogout = 'เมนู - ออกจากโปรแกรม';
  static const userAdminPermissionApprovalView =
      'อนุมัติรายการ - ดูหน้าอนุมัติ';
  static const userAdminPermissionApprovalApprove = 'อนุมัติรายการ - อนุมัติ';
  static const userAdminPermissionApprovalReject = 'อนุมัติรายการ - ไม่อนุมัติ';
  static const userAdminPermissionBudgetSourceView = 'แหล่งเงิน - ดูข้อมูล';
  static const userAdminPermissionBudgetSourceCreate = 'แหล่งเงิน - เพิ่ม';
  static const userAdminPermissionBudgetSourceUpdate = 'แหล่งเงิน - แก้ไข';
  static const userAdminPermissionBudgetSourceDelete = 'แหล่งเงิน - ลบ';
  static const userAdminPermissionIncomeDelete = 'บันทึกรับเงิน - ลบรายการ';
  static const userAdminPermissionFormsDocNoManualEdit =
      'แบบฟอร์มเอกสาร - แก้ไขเลขเอกสารด้วยตนเอง';
  static const userAdminPermissionSettingView = 'ตั้งค่า - เข้าหน้าตั้งค่า';
  static const userAdminPermissionUserAdminView = 'ผู้ใช้ระบบ - ดูข้อมูล';
  static const userAdminPermissionUserAdminCreate = 'ผู้ใช้ระบบ - เพิ่มผู้ใช้';
  static const userAdminPermissionUserAdminResetPassword =
      'ผู้ใช้ระบบ - รีเซ็ตรหัสผ่าน';
  static const userAdminPermissionUserAdminUpdateRole =
      'ผู้ใช้ระบบ - เปลี่ยนบทบาท';
  static const userAdminPermissionUserAdminToggleActive =
      'ผู้ใช้ระบบ - เปิด/ปิดการใช้งาน';
  static const userAdminPermissionUserAdminPermissionManage =
      'ผู้ใช้ระบบ - จัดการสิทธิ์กลุ่ม';
  static const userAdminPermissionAuditLogView =
      'บันทึกการใช้งาน - ดู Audit Log';
  static const userAdminPermissionMenuConfigure =
      'เมนูหลัก - ตั้งค่าเมนู (ชื่อ/ลำดับ/แสดง)';
  static const userAdminTemplateFinanceOfficer = 'เจ้าหน้าที่การเงิน';
  static const userAdminTemplateApproverLead = 'หัวหน้าอนุมัติ';
  static const userAdminTemplateReportAuditor = 'ผู้ดูรายงาน/ตรวจสอบ';
  static const userAdminTemplateAdmin = 'ผู้ดูแลระบบ';
  static const invalidEmail = 'รูปแบบอีเมล์ไม่ถูกต้อง';
  static const userPasswordHelper =
      'กำหนดรหัสผ่านเริ่มต้นอย่างน้อย 6 ตัวอักษร ผู้ใช้ควรเปลี่ยนหลังเข้าใช้งานครั้งแรก';
  static const userPasswordEditHelper =
      'เว้นว่างไว้หากไม่ต้องการเปลี่ยนรหัสผ่าน';
  static const usernameRequired = 'ชื่อผู้ใช้ไม่ควรเป็นค่าว่าง';
  static const userDisplayRequired = 'ชื่อผู้ใช้งานต้องไม่เป็นค่าว่าง';
  static const passwordRequired = 'รหัสผ่านไม่ควรเป็นค่าว่าง';
  static const genericError = 'เกิดข้อผิดพลาด';
  static const requiredCode = 'รหัสต้องไม่เป็นค่าว่าง';
  static const requiredName = 'ชื่อต้องไม่เป็นค่าว่าง';
  static const requiredLastName = 'นามสกุลต้องไม่เป็นค่าว่าง';

  // Income type
  static const incomeTypeName = 'ชื่อหมวดรายรับ';
  static const incomeTypeNameRequired = 'ชื่อหมวดรายรับต้องไม่เป็นค่าว่าง';
  static const nameRequired = 'ชื่อไม่ควรเป็นค่าว่าง';
  static const sourceGroup = 'แหล่งเงิน';
  static const bankAccount = 'บัญชีธนาคาร';
  static const addBankAccount = 'เพิ่มบัญชีธนาคาร';
  static const bankName = 'ชื่อธนาคาร';
  static const bankNameRequired = 'กรุณาเลือกธนาคาร';
  static const bankAccountName = 'ชื่อบัญชี';
  static const bankAccountNumber = 'เลขที่บัญชี';
  static const bankAccountNumberRequired = 'เลขที่บัญชีต้องไม่เป็นค่าว่าง';
  static const bankOpeningBalance = 'ยอดเงินในบัญชียกมา (บาท)';
  static const bankOpeningBalanceHint =
      'ยอดคงเหลือในบัญชี ณ วันเริ่มใช้ระบบหรือต้นปีงบ (ถ้าไม่มีใส่ 0)';

  // Cheque account (บัญชีเช็ค — ทะเบียนจ่ายเช็ค คู่มือหน้า 39)
  static const chequeAccountPageTitle = 'บัญชีเช็ค';
  static const chequeAccountManageSubtitle =
      'กำหนดเล่มเช็ค/บัญชีที่ใช้สั่งจ่าย — อ้างอิงเมื่อบันทึกรายจ่ายแบบเช็ค';
  static const chequeAccountAdd = 'เพิ่มบัญชีเช็ค';
  static const chequeAccountEdit = 'แก้ไขบัญชีเช็ค';
  static const chequeAccountNameLabel = 'ชื่อบัญชีเช็ค';
  static const chequeAccountNameRequired = 'กรุณาระบุชื่อบัญชีเช็ค';
  static const chequeAccountNoLabel = 'เลขที่บัญชีเช็ค / เลขเริ่มต้นในเล่ม';
  static const chequeAccountNoRequired = 'กรุณาระบุเลขบัญชีเช็คหรือเลขเริ่มต้น';
  static const chequeAccountNoHelper =
      'เลขที่พิมพ์บนตราเช็คหรือเลขเริ่มต้นของเล่ม — ใช้คุมไม่ให้ซ้ำในระบบ';
  static const chequeAccountEmptyTitle = 'ยังไม่มีบัญชีเช็ค';
  static const chequeAccountEmptyMessage =
      'เพิ่มบัญชีเช็คที่ผูกกับธนาคารก่อนบันทึกรายจ่ายแบบสั่งจ่ายเช็ค';
  static const chequeAccountSaved = 'บันทึกบัญชีเช็คเรียบร้อย';
  static const chequeAccountDeleted = 'ลบบัญชีเช็คเรียบร้อย';
  static const chequeAccountDeactivateConfirm =
      'ปิดใช้งานบัญชีเช็คนี้? จะไม่แสดงในรายการสั่งจ่ายเช็ค';
  static const chequeAccountDeleteConfirm =
      'ลบบัญชีเช็คนี้ถาวร? รายการจ่ายเช็คเดิมยังอ้างอิงได้';
  static const chequeAccountInUseWarning =
      'บัญชีนี้ถูกใช้ในประวัติจ่ายเช็ค — แนะนำปิดใช้งานแทนการลบ';
  static const chequeAccountSyncFailedLocalSaved =
      'บันทึกในเครื่องแล้ว — ซิงก์ขึ้นเซิร์ฟเวอร์ไม่สำเร็จ (จะซิงก์เมื่อสำรองข้อมูล)';
  static const chequeAccountActiveLabel = 'เปิดใช้งานบัญชีเช็ค';
  static const chequeAccountInactiveLabel = 'ปิดใช้งานแล้ว';
  static const chequeAccountDeactivate = 'ปิดใช้งาน';
  static const chequeAccountSavingBusy = 'กำลังบันทึกบัญชีเช็ค...';
  static const chequeAccountDeletingBusy = 'กำลังลบบัญชีเช็ค...';

  // Money group (ประเภทเงินตามระเบียบการคลัง — ใช้จำแนก budget_source)
  static const moneyGroupLabel = 'ประเภทเงิน';
  static const moneyGroupRequiredLabel = 'ประเภทเงิน *';
  static const moneyGroupSelectHint = 'กรุณาเลือก';
  static const moneyGroupRequired = 'กรุณาเลือกประเภทเงิน';
  static const moneyGroupNone = '-';

  // Budget source
  static const budgetTypeGov = 'งปม';
  static const budgetTypeNonGov = 'นอกงปม';
  static const budgetTypeGeneralGrant = 'อุดหนุนทั่วไป';
  static const budgetTypeSpecificGrant = 'อุดหนุนเฉพาะกิจ';
  static const budgetTypeSchoolIncome = 'รายได้สถานศึกษา';
  static const addBudgetSource = 'เพิ่มแหล่งเงิน';
  static const editBudgetSource = 'แก้ไขแหล่งเงิน';
  static const budgetSourceCodeRequired = 'รหัสแหล่งเงิน *';
  static const budgetSourceNameRequired = 'ชื่อแหล่งเงิน *';
  static const fiscalYearBuddhistRequired = 'ปีงบประมาณ (พ.ศ.) *';
  static const budgetAmountBahtRequired = 'วงเงินงบประมาณ (บาท) *';
  static const budgetAmountBaht = 'วงเงินงบประมาณ (บาท)';
  static const broughtForwardBudget = 'เงินงบยกมา (บาท)';
  static const broughtForwardBudgetHint =
      'เงินงบคงเหลือจากปีก่อนที่นำมาใช้ในปีงบนี้ (รวมกับวงเงินจัดสรรปีนี้)';
  static const totalBudgetEnvelope = 'วงเงินรวม (ยกมา + ปีนี้)';
  static const menuBudgetAmounts = 'ตั้งวงเงินและยกยอดมา';
  static const budgetCategory = 'ประเภทงบประมาณ';
  static const description = 'คำอธิบาย';
  static const saveSuccessDone = 'บันทึกข้อมูลเรียบร้อย';
  static const confirmDelete = 'ยืนยันการลบ';
  static const confirmDeleteBudgetSource = 'ต้องการลบแหล่งเงิน "%s" หรือไม่?';
  static const deleteSuccess = 'ลบข้อมูลเรียบร้อย';
  static const emptyBudgetSource = 'ยังไม่มีข้อมูลแหล่งเงิน';
  static const fiscalYearPrefix = 'ปีงบประมาณ ';
  static const budgetLimit = 'วงเงินรายปี';
  static const used = 'ใช้แล้ว';
  static const remaining = 'คงเหลือ';
  static const usedOfTotalBudget = '% ของวงเงินทั้งหมด';

  // Approval
  static const pendingApproval = 'รออนุมัติ';
  static const approved = 'อนุมัติแล้ว';
  static const rejected = 'ไม่อนุมัติ';
  static const approveConfirmTitle = 'ยืนยันการอนุมัติ';
  static const withdrawDocPrefix = 'ใบขอเบิก: ';
  static const amountPrefix = 'ยอดเงิน: ';
  static const optionalRemark = 'หมายเหตุ (ถ้ามี)';
  static const approveAction = 'อนุมัติ';
  static const approveSuccess = 'อนุมัติเรียบร้อยแล้ว';
  static const rejectWithdrawTitle = 'ปฏิเสธใบขอเบิก';
  static const rejectReasonRequired = 'เหตุผลที่ไม่อนุมัติ *';
  static const pleaseProvideReason = 'กรุณาระบุเหตุผล';
  static const rejectAction = 'ปฏิเสธ';
  static const rejectSuccess = 'ปฏิเสธใบขอเบิกเรียบร้อยแล้ว';
  static const approvalWorkflow = 'Workflow อนุมัติ';
  static const requesterPrefix = 'ผู้ขอ: ';
  static const budgetSourcePrefix = 'แหล่งเงิน: ';
  static const reasonPrefix = 'เหตุผล: ';
  static const approvedByPrefix = 'อนุมัติโดย: ';
  static const approvalLastUpdatedPrefix = 'อัปเดตล่าสุด: ';
  static const approvalNeverUpdatedFromServer = 'ยังไม่เคยดึงจากเซิร์ฟเวอร์';
  static const approvalSyncingWithServer = 'กำลังส่งข้อมูล…';
  static const approvalRefreshFromServer = 'ดึงล่าสุด';
  static String approvalRefreshWaitSeconds(int seconds) => 'รอ $seconds วินาที';
  static const approvalEmptyPendingTitle = 'ไม่มีใบขอเบิกรออนุมัติ';
  static const approvalEmptyPendingHint =
      'ดึงหน้าจอลงเพื่อโหลดใหม่ หรือแตะ “ดึงล่าสุด” ด้านบน';
  static const approvalEmptyApprovedTitle = 'ยังไม่มีรายการที่อนุมัติแล้ว';
  static const approvalEmptyApprovedHint = 'รายการที่อนุมัติจะแสดงที่แท็บนี้';
  static const approvalEmptyRejectedTitle = 'ยังไม่มีรายการที่ไม่อนุมัติ';
  static const approvalEmptyRejectedHint =
      'รายการที่ปฏิเสธจะแสดงที่นี่ พร้อมเหตุผล (ถ้ามี)';
  static const approvalPermissionApproveOnlyHint =
      'บัญชีนี้มีสิทธิ์อนุมัติเท่านั้น ไม่สามารถปฏิเสธใบขอเบิกได้';
  static const approvalPermissionRejectOnlyHint =
      'บัญชีนี้มีสิทธิ์ปฏิเสธเท่านั้น ไม่สามารถอนุมัติใบขอเบิกได้';
  static const approvalPermissionViewOnlyHint =
      'บัญชีนี้ดูรายการได้เท่านั้น ไม่มีสิทธิ์อนุมัติหรือปฏิเสธ โปรดติดต่อผู้ดูแลระบบ';
  static const approvalLogTitle = 'ประวัติการอนุมัติ';
  static const approvalLogEmpty = 'ยังไม่มีประวัติการดำเนินการ';
  static const approvalLogViewAction = 'ดูประวัติ';
  static const approvalLogActionSubmit = 'ส่งขออนุมัติ';
  static const approvalLogActionApprove = 'อนุมัติ';
  static const approvalLogActionReject = 'ปฏิเสธ';

  // ใบขอเบิก (expense_req workflow)
  static const expenseReqTabLabel = 'ใบขอเบิก';
  static const navSectionTransactions = 'ธุรกรรมรับ-จ่าย';
  static const navSectionApprovalExpense = 'การอนุมัติเบิกจ่าย';
  static const expenseReqAddTitle = 'สร้างใบขอเบิก';
  static const expenseReqPageGuideTitle = 'คู่มือสร้างใบขอเบิก';
  static const expenseReqRequiredBeforeSaveHint =
      'กรอกช่องที่มี * ให้ครบก่อนบันทึก: ผู้ขอเบิก, แหล่งเงิน, หมวดทะเบียนคุม และจำนวนเงิน — หลังบันทึกระบบจะตั้งสถานะรออนุมัติอัตโนมัติ';
  static const expenseReqQuickGuideHint =
      'เลือกผู้ขอเบิกและแหล่งเงินให้ตรงรายการที่ต้องการเบิก ระบบจะบันทึกร่างอัตโนมัติเมื่อข้อมูลสำคัญครบ และเมื่อกดบันทึกจะเข้าสถานะรออนุมัติ';
  static const expenseReqRequesterLabel = 'ผู้ขอเบิก';
  static const expenseReqFundCategoryLabel = 'หมวดทะเบียนคุม (OB)';
  static const expenseReqSaveDraft = 'บันทึกร่าง';
  static const expenseReqSaveAndSubmit = 'บันทึก';
  static const expenseReqSubmitAction = 'บันทึก';
  static const expenseReqDraftSaved = 'บันทึกร่างใบขอเบิกเรียบร้อยแล้ว';
  static const expenseReqSubmitSuccess =
      'บันทึกใบขอเบิกเรียบร้อยแล้ว รออนุมัติ';
  static const expenseReqDeleteDraftTitle = 'ลบใบขอเบิกฉบับร่าง';
  static String expenseReqDeleteDraftMessage(String docNo) =>
      'ต้องการลบใบขอเบิกฉบับร่าง "$docNo" หรือไม่?';
  static const expenseReqDeleteDraftSuccess = 'ลบใบขอเบิกฉบับร่างเรียบร้อยแล้ว';
  static const autoDraftSaving = 'กำลังบันทึกร่างอัตโนมัติ...';
  static const autoDraftSaved = 'บันทึกร่างอัตโนมัติแล้ว';
  static const autoDraftWaiting = 'ระบบจะบันทึกร่างเมื่อข้อมูลสำคัญครบ';
  static const autoDraftFailed = 'บันทึกร่างอัตโนมัติไม่สำเร็จ';
  static const expenseReqEmpty = 'ยังไม่มีใบขอเบิก — แตะปุ่มด้านล่างเพื่อสร้าง';
  static const expenseReqStatusDraft = 'ร่าง';
  static const expenseReqMemberRequired = 'กรุณาเลือกผู้ขอเบิก';
  static const expenseReqAmountRequired = 'กรุณาระบุจำนวนเงิน';
  static const expenseReqFundCategoryRequired = 'กรุณาเลือกหมวดทะเบียนคุม';
  static const expenseFromApprovedReqPrefix = 'อ้างอิงใบขอเบิก: ';
  static const expenseEntryFromApprovedReqSubtitle =
      'บันทึกเบิกจริงจากใบขอเบิกที่อนุมัติแล้ว — ตรวจสอบยอดและรูปแบบการจ่ายก่อนบันทึก';
  static const expenseEntryPrefillHint =
      'ระบบเติมข้อมูลจากใบขอเบิกให้แล้ว กรุณาเลือกรูปแบบการจ่ายให้ตรงจริง';
  static const expenseReqReferenceLabel = 'อ้างอิงใบขอเบิก';
  static const expenseReqReferencePickerTitle = 'เลือกใบขอเบิก';
  static const expenseReqReferencePickerHint = 'เลือกใบขอเบิกที่อนุมัติแล้ว';
  static const expenseReqReferenceSearchHint = 'ค้นหาเลขที่หรือผู้ขอเบิก';
  static const expenseReqReferenceLoading = 'กำลังโหลดใบขอเบิก...';
  static const expenseReqReferenceEmpty =
      'ยังไม่มีใบขอเบิกที่อนุมัติแล้วสำหรับบันทึกเบิกจริง';
  static const expenseReqReferenceHelper =
      'เลือกใบขอเบิกเพื่อเติมผู้รับเงิน แหล่งเงิน หมวดทะเบียนคุม และยอดเงิน';
  static const expensePostFromApprovalAction = 'บันทึกเบิกจริง';
  static const expenseOpenEntryAfterApprove = 'เปิดฟอร์มบันทึกเบิก…';
  static const expenseEntryPrefillResolveFailed =
      'ไม่สามารถเติมข้อมูลจากใบขอเบิกได้ — ลองบันทึกเบิกด้วยตนเอง';
  static const expenseReqOpenExpenseTitle = 'เปิดหน้าเบิกจริงต่อหรือไม่';
  static const expenseReqOpenExpenseBody =
      'บันทึกใบขอเบิกสำเร็จแล้ว ต้องการเปิดหน้าเบิกจริงและเติมข้อมูลจากใบขอเบิกนี้หรือไม่';
  static const expenseReqOpenExpenseConfirm = 'เปิดหน้าเบิกจริง';
  static const expenseReqOpenExpenseCancel = 'กลับไปหน้ารายการ';

  // Reports
  static const fiscalYearBuddhist = 'ปีงบประมาณ (พ.ศ.)';
  static const view = 'ดู';
  static const refresh = 'รีเฟรช';
  static const overviewTab = 'ภาพรวม';
  static const monthlyTab = 'รายเดือน';
  static const budgetSourceTab = 'แหล่งเงิน';
  static const trialBalanceTab = 'งบทดลอง';
  static const budgetRemainingTab = 'วงเงินคงเหลือรายปี';
  static const totalIncome = 'รายรับรวม';
  static const totalExpense = 'รายจ่ายรวม';
  static const totalBalance = 'ยอดคงเหลือ';
  static const totalLoan = 'ยอดเงินยืมรวม';
  static const totalRepay = 'ยอดชำระคืนรวม';
  static const monthlySummaryFiscalYear = 'สรุปรายเดือน ปีงบประมาณ ';
  static const receiveShort = 'รับ';
  static const payShort = 'จ่าย';
  static const budgetUsedPercentSuffix = '% ของวงเงิน';
  static const unspecified = 'ไม่ระบุ';
  static const income = 'รายรับ';
  static const expense = 'รายจ่าย';
  static const totalIncomeLabel = 'รวมรายรับ';
  static const totalExpenseLabel = 'รวมรายจ่าย';
  static const netProfitLoss = 'กำไร/ขาดทุนสุทธิ';
  static const overBudget = 'เกินวงเงิน';
  static const allocated = 'วงเงินตั้งต้น';
  static const usedPercentPrefix = 'ใช้ไปแล้ว ';
  static const thaiMonthShort = [
    '',
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.'
  ];

  // Offline / sync widgets
  static const offlineBadgeLabel = 'ออฟไลน์';
  static const offlineWorkingMessage =
      'ออฟไลน์ — ใช้ข้อมูลในเครื่อง; จะส่งขึ้นเซิร์ฟเวอร์เมื่อเชื่อมต่อได้';
  static const offlineLocalOnlyWorkingMessage =
      'ทำงาน Offline — ใช้ข้อมูลในเครื่องและไม่ส่งขึ้นเซิร์ฟเวอร์';
  static const syncStatus = 'คิวส่งขึ้นเซิร์ฟเวอร์';
  static const syncPendingQueueCount = 'รายการรอส่งขึ้นเซิร์ฟเวอร์';
  static const syncNowButton = 'ส่งตอนนี้';
  static const syncInProgress = 'กำลังส่งขึ้นเซิร์ฟเวอร์…';
  static const syncPendingBadge = 'รอส่งเซิร์ฟเวอร์';
  static const syncQueuedNotification = 'เพิ่มเข้าคิวแล้ว';
  static const syncQueuedMessage =
      'บันทึกข้อมูลไว้ในเครื่องแล้ว ระบบจะส่งขึ้นเซิร์ฟเวอร์เมื่อพร้อม';
  static const syncSyncingNotification = 'กำลังซิงก์ข้อมูล';
  static const syncWarningNotification = 'ซิงก์ไม่ครบ';
  static const syncSuccessNotification = 'ซิงก์สำเร็จ';
  static const syncNoPendingMessage = 'ไม่มีรายการรอส่งขึ้นเซิร์ฟเวอร์';
  static const syncManualTooltip = 'ส่งข้อมูลที่รอซิงก์';
  static const appBarNotificationTooltip = 'แตะเพื่อล้างการแจ้งเตือน';
  static const appBarNoNotificationTooltip = 'ยังไม่มีการแจ้งเตือน';

  static String syncPartialFailedMessage(int failedCount, int pendingCount) =>
      'ส่งไม่สำเร็จ $failedCount รายการ เหลือรอส่ง $pendingCount รายการ';

  static String syncCompletedMessage(int syncedCount) =>
      'ส่งข้อมูลขึ้นเซิร์ฟเวอร์แล้ว $syncedCount รายการ';

  /// บรรทัดเสริมหลังบันทึกสำเร็จแบบ local-first — แยกเครื่อง vs เซิร์ฟเวอร์
  static const _syncNoteLocalSaved =
      '• ในเครื่อง: บันทึกลงฐานข้อมูลในเครื่องแล้ว';
  static const _syncNoteServerAuto =
      '• เซิร์ฟเวอร์: จะส่งข้อมูลขึ้นเซิร์ฟเวอร์โดยอัตโนมัติเมื่อพร้อม';
  static const _syncNoteServerPendingOffline =
      '• เซิร์ฟเวอร์: ยังไม่ส่ง — จะส่งเมื่อเชื่อมต่อเซิร์ฟเวอร์ได้';

  /// ต่อท้ายหัวข้อความสำเร็จ (บรรทัดแรก) ด้วยคำอธิบายเครื่อง/เซิร์ฟเวอร์
  static String saveSuccessWithLocalServerNote(
    String headline, {
    required bool serverReachable,
  }) {
    final serverLine =
        serverReachable ? _syncNoteServerAuto : _syncNoteServerPendingOffline;
    return '$headline\n\n$_syncNoteLocalSaved\n$serverLine';
  }

  // Home dashboard
  static const systemOverview = 'ภาพรวมระบบ';
  static const totalIncomeLabelCard = 'รายรับทั้งหมด';
  static const totalExpenseLabelCard = 'รายจ่ายทั้งหมด';
  static const last6MonthsIncomeExpense = 'รายรับ-รายจ่าย 6 เดือนย้อนหลัง';
  static const netBalance = 'ยอดคงเหลือสุทธิ';

  // Generic input hints/tooltips
  static const showPassword = 'แสดงรหัสผ่าน';
  static const hidePassword = 'ซ่อนรหัสผ่าน';
  static const showPin = 'แสดง PIN';
  static const hidePin = 'ซ่อน PIN';
  static const clearDate = 'ล้างวันที่';
  static const pickDate = 'เลือกวันที่';
  static const dateFieldHint = 'วัน/เดือน/ปี';
  static const search = 'ค้นหา...';

  // Setup / API connectivity
  static const apiReadyMessage = 'API พร้อมใช้งาน';
  static const apiResponseError = 'API ตอบกลับผิดพลาด';
  static const connectFailedPrefix = 'เชื่อมต่อไม่ได้: ';
  static const pleaseEnter = 'กรุณากรอก';
  static const numberOnly = 'ตัวเลข';
  static const rootPassword = 'Root Password';
  static const rootPasswordHint = 'รหัสผ่าน root (เว้นว่างได้ถ้าไม่มี)';
  static const dbNameLabel = 'ชื่อฐานข้อมูล (DB Name)';
  static const back = 'ย้อนกลับ';
  static const retry = 'ลองใหม่';
  static const createdTables = 'Tables ที่สร้าง';
  static const noNewMigration = 'ไม่มี migration ใหม่ ฐานข้อมูลทันสมัยแล้ว';
  static const restartingToLoginIn = 'Server กำลัง restart ไปหน้า Login ใน';
  static const seconds = 'วินาที';

  // Common error messages
  /// ข้อความจาก SQLite / sqflite (ลบไม่ได้, ล็อก DB, ฯลฯ)
  static const sqliteForeignKeyBlocked =
      'ลบไม่ได้ เพราะข้อมูลนี้ยังถูกอ้างอิงจากตารางอื่นในระบบ — ต้องจัดการรายการที่เกี่ยวข้องให้ไม่ผูกกับข้อมูลนี้ก่อน';
  static const sqliteDatabaseLocked =
      'ฐานข้อมูลถูกล็อกหรือกำลังถูกใช้งานอยู่ กรุณารอสักครู่แล้วลองใหม่';
  static const sqliteReadOnlyDb =
      'ฐานข้อมูลอยู่ในโหมดอ่านอย่างเดียว ไม่สามารถลบหรือแก้ไขได้';
  static const sqliteUniqueConstraint =
      'ไม่สามารถบันทึกได้ มีข้อมูลซ้ำกับรายการที่มีอยู่แล้ว (เช่น รหัสซ้ำ)';
  static const sqliteDiskIo =
      'เขียนฐานข้อมูลไม่สำเร็จ ตรวจสอบพื้นที่จัดเก็บหรือสิทธิ์เข้าถึงไฟล์';
  static const sqliteSchemaOutdated =
      'โครงสร้างฐานข้อมูลในเครื่องยังไม่ตรงกับเวอร์ชันแอปนี้ กรุณาปิดแล้วเปิดแอปใหม่เพื่อตรวจอัปเดตฐานข้อมูล';
  static const sqfliteWebSetupRequired =
      'ฐานข้อมูลเว็บยังไม่พร้อม — ในโฟลเดอร์ forntend ให้รัน: dart run sqflite_common_ffi_web:setup แล้ว build/deploy ใหม่';

  static const genericTryAgain = 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง';
  static const temporarySystemIssue =
      'ระบบขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง';
  static const requestedDataNotFound = 'ไม่พบข้อมูลที่ร้องขอ';
  static const noPermissionData = 'ไม่มีสิทธิ์เข้าถึงข้อมูลนี้';
  static const invalidDataPleaseCheck = 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง';
  static const connectionTimeout = 'การเชื่อมต่อใช้เวลานานเกินไป';
  static const cannotConnectServer = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
  static const loadBudgetSourceFailed = 'โหลดข้อมูลแหล่งเงินไม่สำเร็จ';
  static const createFailed = 'บันทึกไม่สำเร็จ';
  static const updateFailed = 'อัปเดตไม่สำเร็จ';
  static const deleteFailed = 'ลบไม่สำเร็จ';

  // ── หน้า "ทะเบียนคุม" (สถานศึกษา) ───────────────────────────────
  static const registerPageTitle = 'ทะเบียนคุม';
  static const registerSelectGroupLabel = 'กลุ่มทะเบียน';
  static const registerSelectRegisterLabel = 'ทะเบียนคุม';
  static const registerCurrentRegisterPrefix = 'กำลังเปิด';
  static const registerSequencePrefix = 'ลำดับ';
  static const registerSequenceMiddle = 'จาก';
  static const registerMenuGroupMoney = 'ทะเบียนเงิน';
  static const registerMenuGroupDocument = 'เอกสารการจ่าย';
  static const registerMenuGroupControl = 'ควบคุมและนำส่ง';
  static const registerOffBudgetTabLabel = 'เงินนอกงบประมาณ';
  static const registerEvidenceTabLabel = 'หลักฐานขอเบิก';
  static const registerVoucherTabLabel = 'ใบสำคัญคู่จ่าย';
  static const registerChequeTabLabel = 'จ่ายเช็ค';
  static const registerLoanTabLabel = 'สัญญายืมเงิน';
  static const registerReceiptBookTabLabel = 'ใบเสร็จรับเงิน';
  static const registerDepositGuaranteeTabLabel =
      'เงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย';
  // เพิ่มแท็บทะเบียนคุม: กระแสรายวัน / ส่วนราชการผู้เบิก / รายได้แผ่นดิน
  static const registerCurrentAccountTabLabel = 'เงินฝากธนาคาร (กระแสรายวัน)';
  static const registerAgencyDepositTabLabel = 'สมุดคู่ฝาก ส่วนราชการผู้เบิก';
  static const registerTreasuryRemitTabLabel = 'รับ-นำส่งเงินรายได้แผ่นดิน';
  static const registerDescOffBudget =
      'ติดตามรับ จ่าย และคงเหลือของเงินนอกงบประมาณแยกตามหมวด';
  static const registerDescEvidence =
      'รวบรวมหลักฐานประกอบการขอเบิกก่อนจัดทำรายการจ่าย';
  static const registerDescVoucher =
      'ควบคุมใบสำคัญคู่จ่ายและเอกสารประกอบการเบิกจ่าย';
  static const registerDescCheque =
      'ติดตามการจ่ายเช็ค เลขที่เช็ค และสถานะการขึ้นเงิน';
  static const registerDescLoan = 'ควบคุมสัญญายืมเงิน การส่งใช้ และยอดคงค้าง';
  static const registerDescReceiptBook =
      'ควบคุมเล่มใบเสร็จ เลขที่ใช้แล้ว และเลขที่คงเหลือ';
  static const registerDescDepositGuarantee =
      'ติดตามเงินประกันสัญญาและภาษีหัก ณ ที่จ่ายที่ต้องคืนหรือนำส่ง';
  static const registerDescCurrentAccount =
      'ตรวจสอบเงินฝากธนาคารประเภทกระแสรายวันพร้อมยอดคงเหลือ';
  static const registerDescAgencyDeposit =
      'ควบคุมสมุดคู่ฝากกับส่วนราชการผู้เบิก';
  static const registerDescTreasuryRemit =
      'ติดตามการรับและนำส่งเงินรายได้แผ่นดิน';
  static const registerCurrentAccountHeader =
      'ทะเบียนคุมเงินฝากธนาคาร ประเภทกระแสรายวัน (ฝาก/ถอน/คงเหลือ)';
  static const registerAgencyDepositHeader =
      'สมุดคู่ฝากส่วนราชการผู้เบิก (ฝาก/ถอน/คงเหลือ)';
  static const registerTreasuryRemitHeader =
      'ทะเบียนคุมรับและนำส่งเงินรายได้แผ่นดิน (รับเงิน/นำส่งคลัง/คงเหลือ)';
  static const registerOffBudgetCategoryLabel = 'หมวดเงินนอกงบประมาณ';
  static const registerOpeningBalance = 'ยอดยกมา';
  static const registerEndingBalance = 'ยอดยกไป';
  static const registerTotalIn = 'รวมรับ';
  static const registerTotalOut = 'รวมจ่าย';
  static const registerMonthlySummaryHeader = 'สรุปรายเดือน (ต.ค. – ก.ย.)';
  static const registerLinesHeader = 'รายการเคลื่อนไหว';
  static const registerOffBudgetAllCategoriesTitle =
      'สรุปทุกหมวดเงินนอกงบประมาณ (รับ / จ่าย / คงเหลือสะสมรวมในปีงบนี้)';
  static const registerColRunningBalanceTotal = 'คงเหลือสะสม (รวม)';
  static const registerMonthColMonth = 'เดือน';
  static const registerNoData = 'ยังไม่มีข้อมูล';
  static const registerNoLines = 'ไม่มีรายการในช่วงปีงบประมาณที่เลือก';
  static const registerOffBudgetLoadIncomplete = 'ข้อมูลไม่ครบถ้วน';

  /// หัวคอลัมน์ทะเบียนคุม (ใช้ร่วมกับแท็บกระแสรายวัน / ส่วนราชการผู้เบิก / รายได้แผ่นดิน)
  static const registerColDate = 'วัน เดือน ปี';
  static const registerColDocNo = 'ที่เอกสาร';
  static const registerColDetail = 'รายการ';
  static const registerColDeposit = 'ฝาก';
  static const registerColWithdraw = 'ถอน';
  static const registerColBalance = 'คงเหลือ';
  static const registerColRemark = 'หมายเหตุ';
  static const registerColParty = 'ผู้รับฝาก/นำฝาก';
  static const registerColBudgetSource = 'แหล่งเงิน';
  static const registerColReceived = 'รับ';
  static const registerColRemitted = 'นำส่ง';
  static const registerTreasuryRemitNoMoneyGroupNote =
      'ยังไม่พบ money_group "เงินรายได้แผ่นดิน" ใน DB — ทะเบียนนี้จะว่างจนกว่าจะมีการบันทึกแหล่งเงินที่อ้างกลุ่มนี้';

  /// ข้อความ validation ช่องทะเบียนคุม (dialog / ฟอร์มย่อย)
  static const registerFieldRequired = 'กรุณากรอกข้อมูล';
  static const registerPleaseSignInAgain = 'กรุณาเข้าสู่ระบบใหม่';

  // ── ทะเบียนคุม: ใบเสร็จรับเงิน (dialog + ตาราง) ─────────────────
  static const registerReceiptBookAddTitle = 'เพิ่มเล่มใบเสร็จ';
  static const registerReceiptBookEditTitle = 'แก้ไขเล่มใบเสร็จ';
  static const registerReceiptBookAddFab = 'เพิ่มเล่มใบเสร็จ';
  static const registerReceiptBookListHeader =
      'ทะเบียนคุมใบเสร็จรับเงิน — แสดงเล่มและเลขที่ใช้แล้ว';
  static const registerReceiptBookColBookNo = 'เล่มที่';
  static const registerReceiptBookColReceiptType = 'ประเภท';
  static const registerReceiptBookColStartNo = 'เลขที่เริ่ม';
  static const registerReceiptBookColEndNo = 'เลขที่สุดท้าย';
  static const registerReceiptBookColUsed = 'ใช้แล้ว';
  static const registerReceiptBookColAmount = 'ยอดเงิน';
  static const registerReceiptBookColStatus = 'สถานะ';
  static const registerReceiptBookColActions = 'จัดการ';
  static const registerReceiptBookDialogReceiptType = 'ประเภทใบเสร็จ';
  static const registerReceiptBookReceivedFrom = 'รับมาจาก';
  static const registerReceiptBookBookNoHint =
      'ตัวอย่าง: 001 — ระบบเติมเลขถัดไปให้อัตโนมัติ';
  static const registerReceiptBookDuplicate =
      'มีเล่มนี้อยู่แล้วในปีงบประมาณและประเภทใบเสร็จนี้';
  static const registerReceiptBookRangeDigitsRequired =
      'เลขที่เริ่มและเลขที่สุดท้ายต้องมีตัวเลข';
  static const registerReceiptBookRangeInvalid =
      'เลขที่สุดท้ายต้องมากกว่าหรือเท่ากับเลขที่เริ่ม และมีจำนวนหลักเท่ากันหรือมากกว่า';
  static const registerReceiptBookSavedLocal =
      'บันทึกเล่มใบเสร็จไว้ในเครื่องแล้ว';
  static const registerReceiptBookUpdatedLocal =
      'อัปเดตเล่มใบเสร็จไว้ในเครื่องแล้ว';
  static const registerReceiptBookDeletedLocal = 'ลบเล่มใบเสร็จในเครื่องแล้ว';
  static const registerReceiptBookDeleteTitle = 'ลบเล่มใบเสร็จ';
  static const registerReceiptBookDeleteBlocked =
      'ลบเล่มใบเสร็จไม่ได้ เพราะมีการใช้ใบเสร็จแล้ว';
  static const registerReceiptBookLockedUsed =
      'เล่มนี้มีการใช้ใบเสร็จแล้ว แก้ไขได้เฉพาะรับมาจากและหมายเหตุ';
  static const registerReceiptBookTypeBr = 'บร. — ใบเสร็จรับเงิน';
  static const registerReceiptBookTypeBk = 'บค. — ใบสำคัญรับเงิน';
  static const registerReceiptBookTypeBf = 'บฝ. — ใบฝาก';

  // ── ทะเบียนคุม: เงินประกัน / ภาษีหัก ณ ที่จ่าย ───────────────────
  static const registerDepositAddTitle = 'เพิ่มเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositAddFab = 'เพิ่มเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositListHeader =
      'เงินประกันสัญญา / ภาษีหัก ณ ที่จ่าย — เงินที่ต้องคืนผู้มีสิทธิ์';
  static const registerDepositFilterLabel = 'สถานะ';
  static const registerDepositStatusAll = 'ทั้งหมด';
  static const registerDepositStatusHolding = 'ถือไว้';
  static const registerDepositStatusReturned = 'คืนแล้ว';
  static const registerDepositStatusSubmitted = 'นำส่งแล้ว';
  static const registerDepositStatusForfeited = 'ริบ';
  static const registerDepositTypeContractGuarantee = 'เงินประกันสัญญา';
  static const registerDepositTypeWithholdingTax = 'ภาษีหัก ณ ที่จ่าย';
  static const registerDepositTypeOther = 'อื่น ๆ';
  static const registerDepositPartyLabel = 'คู่สัญญา/ผู้รับคืน';
  static const registerDepositContractNoLabel = 'เลขที่สัญญา';
  static const registerDepositDueDateIsoHint = 'วันครบกำหนดคืน';
  static const registerDepositSettleTitle = 'บันทึกการคืน/นำส่ง';
  static const registerDepositSettleAction = 'การดำเนินการ';
  static const registerDepositSettleReturned = 'คืนผู้มีสิทธิ์';
  static const registerDepositSettleSubmitted = 'นำส่งคลัง/สรรพากร';
  static const registerDepositSettleForfeited = 'ริบ';
  static const registerDepositSettledDocNo = 'เลขที่เอกสารคืน';
  static const registerDepositActionSettle = 'คืน/นำส่ง';
  static const registerDepositColDate = 'วันที่';
  static const registerDepositColDocNo = 'เลขที่';
  static const registerDepositColType = 'ประเภท';
  static const registerDepositColAmount = 'จำนวน';
  static const registerDepositColParty = 'คู่สัญญา';
  static const registerDepositColContract = 'สัญญา';
  static const registerDepositColDue = 'กำหนดคืน';
  static const registerDepositColStatus = 'สถานะ';
  static const registerDepositColAction = 'การดำเนินการ';
  static const registerDepositAddPageTitle = 'รับเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositSettlePageTitle =
      'คืนเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositAddPageGuideTitle =
      'คู่มือรับเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositSettlePageGuideTitle =
      'คู่มือคืนเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const registerDepositBudgetSourceLabel =
      'แหล่งเงิน (ประเภทประกัน/ภาษีหัก)';
  static const registerDepositMoneyTypeLabel = 'ช่องทางเงิน (สด/ฝาก/สปช.)';
  static const registerDepositIncomeTypeLabel = 'หมวดรายรับ';
  static const registerDepositLinkedIncomeHint =
      'บันทึกพร้อมใบรับเงิน — ยอดจะสะท้อนรายงานเงินคงเหลือหน้า 34';
  static const registerDepositLinkedExpenseHint =
      'บันทึกพร้อมใบจ่าย — ปิดรายการทะเบียนและหักยอดคงเหลือ';
  static const registerDepositRequiredBeforeSaveHint =
      'กรอกประเภท, วันที่, เลขที่, จำนวนเงิน, หมวดรายรับ, แหล่งเงิน และช่องทางเงินให้ครบก่อนบันทึก';
  static const registerDepositSettleRequiredBeforeSaveHint =
      'ตรวจสอบเลขที่เอกสารคืนและการดำเนินการให้ถูกต้องก่อนบันทึกคืนหรือนำส่ง';
  static const registerDepositSaveSuccess =
      'บันทึกรับเงินและทะเบียนเรียบร้อยแล้ว';
  static const registerDepositSettleSuccess = 'บันทึกการคืน/นำส่งเรียบร้อยแล้ว';
  static const registerDepositNoBudgetSource =
      'ยังไม่มีแหล่งเงินประเภทนี้ — ตั้งค่าในเมนูแหล่งเงิน (refmoneygroup ประกันสัญญาหรือภาษีหัก ณ ที่จ่าย)';
  static const registerDepositReconcileAction = 'กระทบยอด';
  static const registerDepositReconcileTitle = 'กระทบยอดทะเบียนกับบัญชี';
  static const registerDepositReconcileBalanced = 'ยอดสอดคล้องกัน';
  static const registerDepositReconcileUnbalanced =
      'ยอดไม่ตรง — ตรวจสอบใบรับ/ใบจ่าย';
  static const registerDepositReconcileRegister = 'ทะเบียนถือไว้ (holding)';
  static const registerDepositReconcileLedger = 'ยอดสุทธิบัญชี (รับ−จ่าย)';
  static const registerDepositReconcileDiff = 'ต่าง';
  static const registerDepositColIncomeDoc = 'ใบรับ';
  static const registerDepositColExpenseDoc = 'ใบจ่าย';
  static const registerDepositSyncNote =
      'รายการอัปเดตจากเซิร์ฟเวอร์แล้วเก็บในเครื่อง — ใช้ได้เมื่อออฟไลน์';
  static const registerDepositDueSoonBannerTitle = 'ใกล้ครบกำหนดคืนเงิน';
  static const registerDepositDueSoonBannerOverdue = 'เลยกำหนด';
  static const registerDepositDueSoonBannerUpcoming = 'ภายใน 30 วัน';
  static const registerDepositDueSoonDaysLeft = 'เหลือ';
  static const registerDepositDueSoonDaysOver = 'เลยมา';
  static const registerDepositDueSoonDayUnit = 'วัน';
  static const registerDepositFilterDueSoon = 'ใกล้ครบกำหนด';
  static const registerDepositColLedgerDocs = 'ใบรับ/จ่าย';
  static const registerDepositNoIncomeDoc = '—';
  static const registerDepositSeedBudgetHint =
      'แหล่งเงิน DEP-GUAR / DEP-WHT ถูกสร้างหลัง migrate — ตรวจในเมนูแหล่งเงิน';
  static const registerDepositDetailTitle = 'รายละเอียดทะเบียนเงินประกัน';
  static const registerDepositDetailSection = 'ข้อมูลทะเบียน';
  static const registerDepositDetailLedgerSection = 'เอกสารบัญชีที่เชื่อม';
  static const registerDepositDetailSettleSection = 'การคืน/นำส่ง';
  static const registerDepositDeleteConfirm =
      'ต้องการลบรายการทะเบียนนี้ (เฉพาะสถานะถือไว้ที่ยังไม่มีใบจ่าย) ใช่หรือไม่';
  static const registerDepositDeleteSuccess = 'ลบรายการทะเบียนเรียบร้อยแล้ว';
  static const registerDepositCsvHeader =
      'วันที่,เลขที่,ประเภท,จำนวน,คู่สัญญา,สัญญา,กำหนดคืน,สถานะ,ใบรับ,ใบจ่าย';
  static const registerDepositCsvExportSuccess =
      'ส่งออก CSV เรียบร้อย — คัดลอกไปยังคลิปบอร์ดแล้ว';
  static const homeDepositDueSoonTitle =
      'เงินประกัน/ภาษีหัก ณ ที่จ่าย ใกล้ครบกำหนด';
  static const homeDepositDueSoonTapHint = 'แตะเพื่อเปิดทะเบียนคุม';
  static String homeDepositDueSoonSummary(int overdue, int upcoming) =>
      'เลยกำหนด $overdue รายการ · ภายใน 30 วัน $upcoming รายการ';
  static const registerDepositEditTitle = 'แก้ไขทะเบียนเงินประกัน';
  static const registerDepositSubTabAll = 'ทั้งหมด';
  static const registerDepositPdfExportSuccess = 'ส่งพิมพ์ทะเบียนเรียบร้อยแล้ว';
  static const registerDepositLinkedFormsSection = 'แบบฟอร์มที่เกี่ยวข้อง';
  static const registerDepositFormVoucher = 'ใบสำคัญรับเงิน (จากใบรับที่ผูก)';
  static const registerDepositFormWht = 'หนังสือรับรองหักภาษี ณ ที่จ่าย';
  static const formsCardDepositRegisterTitle =
      'ทะเบียนเงินประกัน/ภาษีหัก ณ ที่จ่าย';
  static const formsCardDepositRegisterDescription =
      'รายงานทะเบียนคุมตามคู่มือหน้า 42 (ดึงจากข้อมูลในระบบ)';
  static const formsCardLoanContractTitle = 'สัญญายืมเงิน';
  static const formsCardLoanContractDescription =
      'พิมพ์ PDF สัญญาการยืมเงินสำหรับแนบรายการยืม';

  // ── หน้า "แบบฟอร์มเอกสาร" ──────────────────────────────────────
  static const formsPageTitle = 'แบบฟอร์มเอกสาร';
  static const formsGeneratePdfAction = 'สร้าง PDF';
  static const formsPrintPdfAction = 'พิมพ์ PDF';
  static const formsPrintPdfTooltip = 'เลือกเครื่องพิมพ์และพิมพ์ PDF';
  static const formsPrintSelectPrinterTitle = 'เลือกเครื่องพิมพ์';
  static const formsPrintSuccess = 'ส่งพิมพ์เรียบร้อยแล้ว';
  static const formsPrintCanceled = 'ยกเลิกการพิมพ์';
  static const formsPrintUnavailable = 'อุปกรณ์นี้ไม่รองรับการพิมพ์ PDF โดยตรง';
  static const formsPrintFailedPrefix = 'พิมพ์ PDF ไม่สำเร็จ:';
  static const formsBusyGeneratingPrefix = 'กำลังสร้าง';
  static const formsGenerateSuccessPrefix = 'สร้าง';
  static const formsGenerateSuccessSuffix = 'สำเร็จ';
  static const formsGenerateFailedPrefix = 'สร้าง PDF ไม่สำเร็จ:';
  static const formsSavedDialogTitle = 'สร้าง PDF สำเร็จ';
  static const formsSavedSizeLabel = 'ขนาด:';
  static const formsSavedAtLabel = 'บันทึกที่:';
  static const formsBusyProcessing = 'กำลังประมวลผล...';
  static const formsReviewBeforeGenerate = 'ตรวจสอบข้อมูลก่อนสร้าง PDF';
  static const formsQuickHint =
      'ตรวจสอบข้อมูลให้ครบถ้วนก่อนพิมพ์เอกสาร PDF โดยเฉพาะวันที่ รายการ และจำนวนเงิน';
  static const formsSectionDocumentInfo = 'ข้อมูลเอกสาร';
  static const formsSectionReceiptList = 'รายการใบเสร็จ';
  static const formsValidationPleaseFillRequired =
      'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน';
  static const formsValidationAmountMustBePositive = 'จำนวนเงินต้องมากกว่า 0';
  static const formsValidationAtLeastOneReceiptItem =
      'กรุณาระบุรายการใบเสร็จอย่างน้อย 1 รายการ';
  static const formsValidationReceiptItemIncomplete =
      'กรุณากรอกเลขที่ รายการ และจำนวนเงินของใบเสร็จให้ครบ';

  static const formsCardReceiptSubstituteTitle =
      'ใบรับรองแทนใบเสร็จรับเงิน (บก.111)';
  static const formsCardReceiptSubstituteDescription =
      'สำหรับรายจ่ายที่ไม่อาจเรียกใบเสร็จได้';
  static const formsCardVoucherReceiveTitle = 'ใบสำคัญรับเงิน (บค.)';
  static const formsCardVoucherReceiveDescription =
      'ใช้เป็นหลักฐานเมื่อจ่ายเงินให้บุคคลทั่วไป (ไม่มีใบเสร็จ)';
  static const formsCardWithholdingTaxTitle =
      'หนังสือรับรองการหักภาษี ณ ที่จ่าย';
  static const formsCardWithholdingTaxDescription =
      'ส่งให้ผู้ถูกหักภาษี (ตามมาตรา 50 ทวิ)';
  static const formsCardReceiptAttachmentTitle = 'ใบแนบใบเสร็จ';
  static const formsCardReceiptAttachmentDescription =
      'รวมรายการใบเสร็จหลายใบให้พิมพ์ในใบเดียว';

  static const formsLabelDocNo = 'เลขที่เอกสาร';
  static const formsLabelDate = 'วันที่';
  static const formsLabelPayerName = 'ชื่อ-สกุลผู้รับรอง';
  static const formsLabelPayerPosition = 'ตำแหน่ง';
  static const formsLabelDetail = 'รายการ';
  static const formsLabelAmount = 'จำนวนเงิน';
  static const formsLabelReceiverName = 'ชื่อผู้รับเงิน';
  static const formsLabelReceiverAddress = 'ที่อยู่ผู้รับเงิน';
  static const formsLabelExpenseDetail = 'เป็นค่า';
  static const formsLabelPayer = 'ชื่อผู้จ่ายเงิน';
  static const formsLabelPayeeName = 'ชื่อผู้ถูกหักภาษี';
  static const formsLabelPayeeTaxId = 'เลขประจำตัวผู้เสียภาษี';
  static const formsLabelAddress = 'ที่อยู่';
  static const formsLabelIncomeKind = 'ประเภทเงินได้';
  static const formsLabelGrossAmount = 'จำนวนเงินที่จ่าย';
  static const formsLabelTaxAmount = 'ภาษีที่หัก ณ ที่จ่าย';
  static const formsLabelSigner = 'ผู้ลงนาม';
  static const formsLabelSubject = 'เรื่อง';
  static const formsLabelReceiptItems = 'รายการใบเสร็จ';
  static const formsLabelReceiptNo = 'เลขที่';
  static const formsLabelPreparerName = 'ผู้จัดทำ';
  static const formsLabelLoanPurpose = 'วัตถุประสงค์';
  static const formsLabelApproverName = 'ผู้อนุมัติ';
  static const formsLabelSelectSignerFromDb = 'เลือกผู้ลงนามจากรายชื่อบุคลากร';
  static const formsLabelSelectPayerFromDb =
      'เลือกผู้จ่ายเงินจากรายชื่อบุคลากร';
  static const formsLabelSelectPreparerFromDb =
      'เลือกผู้จัดทำจากรายชื่อบุคลากร';
  static const formsRegenerateDocNoTooltip = 'สร้างเลขเอกสารใหม่อัตโนมัติ';
  static const formsDocNoGenerateFailed = 'ไม่สามารถสร้างเลขเอกสารอัตโนมัติได้';
  static const formsDocNoAutoOnlyHint =
      'ระบบกำหนดเลขเอกสารอัตโนมัติ (แก้ไขได้เฉพาะผู้ได้รับสิทธิ์)';
  static const formsAddRow = 'เพิ่มแถว';

  // ── รายงานเพิ่มเติม (รายงานเงินคงเหลือประจำวัน / งบเทียบยอดธนาคาร) ──
  static const reportsSelectGroupLabel = 'เลือกหมวด';
  static const reportsSelectReportLabel = 'เลือกรายงาน';
  static const reportsCurrentReportPrefix = 'กำลังดู';
  static const reportsSequencePrefix = 'รายการที่';
  static const reportsSequenceMiddle = 'จาก';
  static const reportsMenuGroupSummary = 'ภาพรวมและสรุป';
  static const reportsMenuGroupBudget = 'งบประมาณและยอดคงเหลือ';
  static const reportsMenuGroupOfficial = 'เงินสด ธนาคาร และรายวัน';
  static const reportsMenuGroupControl = 'ปิดวันและติดตามรายการค้าง';
  static const reportsDescOverview =
      'ดูภาพรวมรายรับ รายจ่าย ยอดคงเหลือ และเงินยืมของปีงบประมาณ';
  static const reportsDescMonthly =
      'ดูแนวโน้มรับ-จ่ายแยกตามเดือน เพื่อเทียบความเคลื่อนไหวในปีงบประมาณ';
  static const reportsDescAnnualSummary =
      'สรุปรายรับ-รายจ่ายประจำปีตามแบบรายงานหลัก';
  static const reportsDescBudgetSource =
      'ตรวจการรับและใช้เงินแยกตามแหล่งเงินหรือโครงการ';
  static const reportsDescTrialBalance =
      'ตรวจยอดรับ-จ่ายแยกตามประเภทเงินเพื่อช่วยตรวจทานบัญชี';
  static const reportsDescBudgetRemaining =
      'ดูงบที่จัดสรร ใช้ไป และคงเหลือของแต่ละแหล่งเงิน';
  static const reportsDescDailyBalance =
      'ดูเงินคงเหลือประจำวัน แยกเงินสด ธนาคาร และส่วนราชการผู้เบิก';
  static const reportsDescDailyCashSummary =
      'สรุปเงินสดยกมา รับสด จ่ายสด และเงินสดยกไปของวันที่เลือก';
  static const reportsDescBankReconciliation =
      'เทียบยอดสมุดเงินฝากกับรายการธนาคารและเช็คค้าง';
  static const reportsDescDailyClosing =
      'ตรวจยอดและบันทึกปิดวันเมื่อข้อมูลพร้อม';
  static const reportsDescLoanOutstanding =
      'ติดตามสัญญายืมเงินที่ยังค้างชำระหรือเกินกำหนด';
  static const reportsDescChequeOutstanding =
      'ดูเช็คที่ออกแล้วแต่ยังไม่ตัดบัญชี เพื่อใช้เทียบยอดธนาคาร';
  static const annualSummaryTab = 'รับ-จ่ายประจำปี (ห.33)';
  static const dailyBalanceTab = 'เงินคงเหลือประจำวัน';
  static const dailyCashSummaryTab = 'สรุปเงินสดรายวัน';
  static const reportsDailyCashSummaryTitle = 'สรุปผลเงินสดท้ายวัน';
  static const reportsDailyCashOpeningLabel = 'ยอดเงินสดยกมา';
  static const reportsDailyCashReceivedCashLabel = 'รับเงินสดในวันนี้';
  static const reportsDailyCashReceivedTransferLabel =
      'รับโอน/ฝากธนาคารในวันนี้';
  static const reportsDailyCashPaidTodayLabel = 'จ่ายเงินสดในวันนี้';
  static const reportsDailyCashClosingLabel = 'ยอดเงินสดยกไป (คำนวณจากรายการ)';
  static const reportsDailyCashSummaryFootnote =
      'ยอดยกไปคำนวณจากยกมา + รับเงินสด − จ่ายเงินสด (รายการโอนไม่เพิ่มเงินสดในมือ)';
  static const bankReconciliationTab = 'งบเทียบยอดธนาคาร';
  static const dailyClosingTab = 'ปิดวัน';
  static const dailyClosingTitle = 'ปิดวันและบันทึกยอดคงเหลือ';
  static const dailyClosingAction = 'ปิดวันนี้';
  static const dailyClosingSuccess =
      'ปิดวันสำเร็จ — บันทึก snapshot รายงานเงินคงเหลือแล้ว';
  static const dailyClosingAlreadyClosed = 'วันนี้ปิดวันแล้ว';
  static const dailyClosingNoteHint = 'หมายเหตุ (ถ้ามี)';
  static const dailyClosingHistoryTitle = 'ประวัติปิดวันล่าสุด';
  static const dailyClosingCashOverBlock =
      'ยอดเงินสดเกินวงเงินเก็บรักษา — นำฝาก/นำส่งก่อนปิดวัน';
  static const complianceAlertsTitle = 'แจ้งเตือนการเงิน';
  static const complianceAlertsEmpty = 'ไม่มีรายการแจ้งเตือนในขณะนี้';
  static const complianceSeverityCritical = 'เร่งด่วน';
  static const complianceSeverityWarning = 'ควรดำเนินการ';
  static const complianceSeverityInfo = 'ข้อมูล';
  static const bankReconNoteTitle = 'บันทึกเหตุผลความต่างยอด';
  static const bankReconNoteReason = 'สาเหตุ';
  static const bankReconNoteAmount = 'จำนวนเงิน (บาท)';
  static const bankReconNoteSaved = 'บันทึกเหตุผลความต่างยอดแล้ว';
  static const bankReconReasonOutstandingCheque = 'เช็คค้างขึ้นเงิน';
  static const bankReconReasonTransferPending = 'โอนเข้าแล้วยังไม่รับ';
  static const bankReconReasonDepositPending = 'นำฝากรอตัดบัญชี';
  static const bankReconReasonFeeAdjustment = 'ปรับค่าธรรมเนียม';
  static const bankReconReasonOther = 'อื่น ๆ';
  static const saveDocAsDraft = 'บันทึกเป็นร่าง';
  static const saveDocAsApproved = 'บันทึกรอลงบัญชี';
  static const saveDocAsPosted = 'บันทึกและลงบัญชี';
  static const expenseDocStatusLabel = 'สถานะเอกสาร';
  static const expenseDocStatusDraft = 'ร่าง';
  static const expenseDocStatusApproved = 'อนุมัติแล้ว';
  static const expenseDocStatusPosted = 'ลงบัญชีแล้ว';
  static const incomeCashOverLimitBlock =
      'ยอดเงินสด/ฝากหลังบันทึกจะเกินวงเงินเก็บรักษา — ต้องนำฝากหรือนำส่งก่อน';
  static const loanOutstandingTab = 'สรุปหนี้ยืมค้าง';
  static const chequeOutstandingTab = 'เช็คค้างตัดบัญชี';
  static const chequeOutstandingHint =
      'เช็คที่ออกแล้วแต่ยังไม่ตัดบัญชี — ใช้ในงบเทียบยอดธนาคาร (หน้า 32)';
  static const chequeOutstandingTotalLabel = 'ยอดเช็คค้างรวม';
  static const chequeOutstandingCountLabel = 'จำนวนใบ';
  static const chequeOutstandingMarkInRegisterHint =
      'ตัดบัญชีได้ที่ เมนูทะเบียนคุม → จ่ายเช็ค (แตะแถวค้างตัด)';
  static const loanOutstandingSummaryTitle =
      'สรุปลูกหนี้เงินยืมคงค้าง (เสนอผู้บริหาร)';
  static const loanOutstandingTotalLabel = 'ยอดค้างชำระรวม';
  static const loanOutstandingContractsLabel = 'สัญญาที่ค้าง';
  static const loanOutstandingOverdueLabel = 'เกินกำหนด';
  static const loanOutstandingEmpty = 'ไม่มียอดค้างชำระ';
  static const loanOutstandingBorrower = 'ผู้ยืม';
  static const loanOutstandingBalance = 'คงค้าง';

  // ── ติดตามการยืมเงิน (Loan management) ──
  static const loanManagementTabLabel = 'ติดตามการยืม';
  static const loanManagementPageTitle = 'ติดตามการยืมเงิน';
  static const loanManagementTotalOutstandingTitle = 'ยอดค้างชำระรวม';
  static const loanManagementBorrowersSection = 'ผู้ที่มีเงินยืมค้างส่ง';
  static const loanManagementLoanDocShort = 'เลขที่ใบยืม';
  static const loanManagementPrincipalShort = 'ยอดยืม';
  static const loanManagementRemainingShort = 'คงค้าง';
  static const loanManagementPartiallyRepaidBadge = 'คืนแล้วบางส่วน';
  static const loanManagementRepayAction = 'Repay';
  static const loanManagementRepaySheetTitle = 'บันทึกคืนเงินยืม';
  static const loanManagementRepayMethodLabel = 'วิธีคืน';
  static const loanManagementRepayMethodCash = 'เงินสด';
  static const loanManagementRepayMethodVoucher = 'ส่งใบสำคัญ';
  static const loanManagementRepayMethodVoucherHint =
      'ระบบจะสร้างใบรายจ่าย (ใบสำคัญคู่จ่าย) อัตโนมัติ';
  static const loanManagementDetailSheetTitle = 'รายละเอียดการยืม';
  static const loanManagementEmptyOutstanding = 'ไม่มีรายการยืมที่ค้างชำระ';
  static const loanManagementExpenseDetailPrefix = 'คืนเงินยืม — เลขที่ใบยืม';
  static const loanManagementExpenseRemarkSuffix = 'จากการคืนเงินยืม';
  static const loanManagementRepayExpenseFailed =
      'บันทึกคืนเงินแล้ว แต่สร้างใบรายจ่ายไม่สำเร็จ ระบบยกเลิกรายการคืนเงินให้';
  static const loanManagementLookupExpenseTypeFailed =
      'ไม่พบประเภทรายจ่ายที่ใช้สร้างใบสำคัญอัตโนมัติ';

  /// แสดงเมื่อโหลดจาก cache แล้ว กำลังดึงข้อมูลล่าสุดจากเซิร์ฟเวอร์เบื้องหลัง
  static const reportsRefreshingFromServer =
      'กำลังอัปเดตข้อมูลล่าสุดจากเซิร์ฟเวอร์…';
  static const reportsDateLabel = 'วันที่';
  static const reportsLoadFailedPrefix = 'โหลดข้อมูลไม่สำเร็จ';
  static const reportsBusyLoading = 'กำลังโหลดรายงาน...';
  static const reportsBusyLoadingLocal = 'กำลังโหลดข้อมูลในเครื่อง...';
  static const reportsBudgetCsvHeader =
      'code,name,budget_total,income_amount,used_expense,remaining,net_balance,used_percent';
  static const reportsCsvCopied = 'คัดลอก CSV แล้ว';
  static const reportsCsvSavedAtPrefix = 'บันทึก CSV ที่';
  static const reportsExcelDownloaded = 'ดาวน์โหลดไฟล์ Excel แล้ว';
  static const reportsExcelSavedAtPrefix = 'บันทึก Excel ที่';
  static const reportsExcelEncodeFailed = 'สร้างไฟล์ Excel ไม่สำเร็จ';
  static const reportsExportTooltip = 'ส่งออกรายงาน';
  static const reportsPrintPdf = 'พิมพ์ PDF';
  static const reportsPrintPdfTooltip = 'พิมพ์รายงานเป็น PDF';
  static const reportsAnnualCsvHeader =
      'section,code,type_name,amount,document_count';
  static const reportsDailyBalanceCsvHeader =
      'category,cash,bank,agency,total,remark';
  static const reportsBankAccountNumberCol = 'เลขบัญชี';
  static const reportsBudgetSourceTotalLabel = 'สรุปรวมตามแหล่งเงิน';
  static const reportsAnnualSummaryHintFillFiscalYear =
      'กรุณาระบุปีงบประมาณ (พ.ศ.) ในช่องด้านบน แล้วกด "ดู"';
  static const reportsAnnualSummaryLoading =
      'กำลังโหลดข้อมูลรับ-จ่ายประจำปี...';
  static const reportsFiscalYearPrefix = 'ปีงบประมาณ พ.ศ.';
  static const reportsAnnualIncomeByType = 'รายรับ (ตามประเภทรายได้)';
  static const reportsAnnualExpenseByRefType =
      'รายจ่าย (ตามประเภทรายได้ที่อ้างในใบจ่าย)';
  static const reportsColCode = 'รหัส';
  static const reportsColType = 'ประเภท';
  static const reportsColAmount = 'จำนวนเงิน';
  static const reportsColDocuments = 'เอกสาร';
  static const reportsDailyColCategory = 'ประเภท';
  static const reportsDailyColCash = 'เงินสด';
  static const reportsDailyColBank = 'ฝากธนาคาร';
  static const reportsDailyColAgency = 'สปช.';
  static const reportsDailyColTotal = 'รวม';
  static const reportsDailyColRemark = 'หมายเหตุ';
  static const reportsDailySevenRowsTitle =
      'รายงานเงินคงเหลือประจำวัน — 7 หมวด';
  static const reportsBankOpeningIncludedNotePrefix =
      'ยอดฝากธนาคารรวมยอดยกมาเปิดบัญชี:';
  static const reportsBankOpeningIncludedNoteSuffix =
      '(รวมในคอลัมน์ฝากธนาคารของยอดรวมด้านล่าง)';
  static const reportsCashTotalLabel = 'เงินสด (รวมทุกหมวด)';
  static const reportsBankTotalLabel = 'เงินฝากธนาคาร (รวมทุกหมวด + ยกมา)';
  static const reportsAgencyTotalLabel = 'เงินฝากส่วนราชการผู้เบิก';
  static const reportsGrandTotalLabel = 'รวมยอดคงเหลือ';
  static const reportsCashOverLimitPrefix = 'เงินสดเกินวงเงินเก็บรักษา';
  static const reportsCashOverLimitSuffix = 'ตามคู่มือ';
  static const reportsBankSummaryTitle = 'สรุปยอดบัญชีธนาคาร (รวมทุกบัญชี)';
  static const reportsBankOpeningLabel = 'ยอดยกมา (opening)';
  static const reportsBankInLabel = '+ รับเข้าผ่านบัญชีธนาคาร';
  static const reportsBankOutLabel = '- จ่ายออกผ่านบัญชีธนาคาร';
  static const reportsBankBookBalanceLabel = 'ยอดในสมุดเงินฝาก';
  static const reportsBankOutstandingChequeLabel =
      '+ เช็คที่ยังไม่ตัด (outstanding)';
  static const reportsBankStatementLabel = 'ยอด Statement (เทียบกับธนาคาร)';
  static const reportsBankAccountsTitle = 'บัญชีธนาคาร';
  static const reportsNoBankAccounts = 'ยังไม่มีบัญชีธนาคาร';
  static const reportsBankUnallocatedTitle =
      'รับ–จ่ายผ่านธนาคารที่ยังระบุบัญชีไม่ได้';
  static const reportsBankUnallocatedSubtitle =
      '(ยัง resolve บัญชีไม่ได้ — ตรวจหัวเอกสาร แหล่งเงิน และประเภทรายรับ)';
  static const reportsBankPerAccountBookHint =
      'ยอดในสมุดรายบัญชี = ยกมา + รับ − จ่าย (เฉพาะรายการที่จบที่บัญชีนี้)';
  static const reportsBankAccountSourceRule =
      'ลำดับการจับคู่บัญชี: หัวเอกสารก่อน แล้วแหล่งเงิน แล้วประเภทรายรับ (ถ้าชั้นบนระบุไว้จะใช้แทนชั้นล่าง)';
  static const reportsBankUnallocatedNetLabel = 'สุทธิ (ไม่รวมยอดเปิดบัญชี)';

  // ── คำสั่งแต่งตั้ง (กรรมการเก็บรักษาเงิน / เจ้าหน้าที่การเงิน ฯลฯ) ──
  static const appointmentOrderPageTitle = 'คำสั่งแต่งตั้ง';
  static const appointmentOrderMenuSubtitle =
      'บันทึกคำสั่งแต่งตั้งกรรมการเก็บรักษาเงินและเจ้าหน้าที่ตามคู่มือ';
  static const appointmentOrderDocNoLabel = 'เลขที่คำสั่ง';
  static const appointmentOrderDocDateLabel = 'วันที่คำสั่ง';
  static const appointmentOrderTypeLabel = 'ประเภทคำสั่ง';
  static const appointmentOrderSubjectLabel = 'เรื่อง';
  static const appointmentOrderContentLabel = 'รายละเอียด / ข้อความในคำสั่ง';
  static const appointmentOrderFiscalYearLabel = 'ปีงบประมาณ (พ.ศ.)';
  static const appointmentOrderStatusLabel = 'สถานะ';
  static const appointmentOrderMembersSection = 'รายชื่อผู้ได้รับแต่งตั้ง';
  static const appointmentOrderMemberNameLabel = 'ชื่อ-นามสกุล';
  static const appointmentOrderMemberPositionLabel = 'ตำแหน่ง';
  static const appointmentOrderMemberRoleLabel = 'บทบาทในคำสั่ง';
  static const appointmentOrderAddMemberRow = 'เพิ่มรายชื่อ';
  static const appointmentOrderMemberRequired =
      'กรุณาระบุชื่อผู้ได้รับแต่งตั้งอย่างน้อย 1 ท่าน';
  static const appointmentOrderTypeFinanceOfficer =
      'แต่งตั้งเจ้าหน้าที่การเงินและบัญชี';
  static const appointmentOrderTypeCashCommittee =
      'แต่งตั้งกรรมการเก็บรักษาเงิน';
  static const appointmentOrderTypeDailyInspector =
      'แต่งตั้งผู้ตรวจสอบรับจ่ายประจำวัน';
  static const appointmentOrderRoleChair = 'ประธาน';
  static const appointmentOrderRoleCommittee = 'กรรมการ';
  static const appointmentOrderRoleSecretary = 'เลขานุการ';
  static const appointmentOrderRoleOfficer = 'เจ้าหน้าที่';
  static const appointmentOrderStatusActive = 'ใช้งาน';
  static const appointmentOrderStatusCancelled = 'ยกเลิก';

  // ── ยอดยกมาต้นปีงบประมาณ (Fiscal Year Opening) ─────────────────
  static const fiscalYearOpeningTitle = 'ยอดยกมาต้นปีงบประมาณ';
  static const fiscalYearOpeningSubtitle =
      'กำหนดยอดเงินคงเหลือต้นปีงบประมาณ (1 ต.ค.) แยกตาม 7 ประเภท × 3 บัญชี';
  static const fiscalYearOpeningTooltip =
      'ใช้สำหรับรายงานเงินคงเหลือประจำวัน\nหากเริ่มใช้ระบบกลางปี ต้องป้อนยอดยกมาเพื่อให้รายงานถูกต้อง';
  static const fiscalYearOpeningSectionRows =
      'ยอดยกมาแยกตามประเภทเงิน × บัญชี (บาท)';
  static const fiscalYearOpeningEmptyHint =
      'ยังไม่ได้กำหนดยอดยกมาของปีนี้ — กรอกค่าให้แต่ละช่องแล้วบันทึก';
  static const fiscalYearOpeningCopyFromPrev = 'คัดลอกจากปีก่อน';
  static const fiscalYearOpeningCopyFromPrevHint =
      'นำยอดปลายปี N-1 มาตั้งเป็นยอดยกมาปีนี้ (year-end close)';
  static const fiscalYearOpeningFetchSuggested = 'ดึงยอดที่ระบบเสนอ';
  static const fiscalYearOpeningFetchSuggestedHint =
      'คำนวณยอด ณ วันที่ 30 ก.ย. จากทรานแซคชันก่อนหน้านี้';
  static const fiscalYearOpeningConfirmCopyTitle = 'ยืนยันคัดลอกยอดจากปีก่อน';
  static const fiscalYearOpeningConfirmCopyMessage =
      'การคัดลอกจะเขียนทับยอดที่ใส่ไว้ของปีนี้ ดำเนินการต่อหรือไม่?';
  static const fiscalYearOpeningSaveSuccess = 'บันทึกยอดยกมาเรียบร้อย';
  static const fiscalYearOpeningSourceManual = 'กรอกเอง';
  static const fiscalYearOpeningSourceComputed = 'คำนวณอัตโนมัติ';
  static const fiscalYearOpeningSourceYearEndClose = 'ปิดยอดปีก่อน';
  static const fiscalYearOpeningRowTotal = 'รวมทั้งแถว';
  static const fiscalYearOpeningGrandTotal = 'รวมทั้งหมด';
  static const fiscalYearOpeningRemarkLabel = 'หมายเหตุ (ทั้งปี)';
}
