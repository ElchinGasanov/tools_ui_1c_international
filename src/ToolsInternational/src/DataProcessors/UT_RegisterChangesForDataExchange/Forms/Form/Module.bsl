&AtClient
Var MetadataCurrentRow;

////////////////////////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	VerifyAccessRights("Administration", Metadata);

	If Parameters.Property("AutoTests") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	RegistrationTableParameter = Undefined;
	RegistrationObjectParameter  = Undefined;
	
//	OpenWithNodeParameter = False;
	CurrentObject = ThisObject();
	
	// Analyzing form parameters.
	If Parameters.CommandID = Undefined Then
		// Starting the data processor in standalone mode.
		ExchangeNodeRef = Parameters.УзелОбмена;
		Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
//		OpenWithNodeParameter = True;

	ElsIf Parameters.CommandID = "OpenRegistrationEditingForm" Then
		If TypeOf(Parameters.RelatedObjects) = Type("Array") And Parameters.RelatedObjects.Count() > 0 Then
			// The form is opened with the specified object.
			RelatedObject = Parameters.RelatedObjects[0];
			Type = TypeOf(RelatedObject);
			If ExchangePlans.AllRefsType().ContainsType(Type) Then
				ExchangeNodeRef = RelatedObject;
//				OpenWithNodeParameter = True;
			Else
				// Filling internal attributes.
				Details = CurrentObject.MetadataCharacteristics(RelatedObject.Metadata());
				If Details.IsReference Then
					RegistrationObjectParameter = RelatedObject;
				ElsIf Details.IsSet Then
					// Structure and table name
					RegistrationTableParameter = Details.TableName;
					RegistrationObjectParameter  = New Structure;
					For Each Dimension In CurrentObject.RecordSetDimensions(RegistrationTableParameter) Do
						CurName = Dimension.Name;
						RegistrationObjectParameter.Insert(CurName, RelatedObject.Filter[CurName].Value);
					EndDo;
				EndIf;
			EndIf;

		Else
			Raise StrReplace(
				NStr("ru='Неверные параметры команды открытия ""%1""'; en = 'Incorrect parameters for the %1 command'"), "%1", Parameters.CommandID);

		EndIf;

	Else
		Raise StrReplace(
			NStr("ru='Undefined command ""%1""'"), "%1", Parameters.CommandID);
	КонецЕсли;
	
	// Initializing object settings.
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	// Initializing other parameters only if this form will be opened.
	If RegistrationObjectParameter <> Undefined Then
		Return;
	EndIf;
	
	// Filling the list of prohibited metadata objects based on form parameters.
	Parameters.Property("NamesOfMetadataToHide", NamesOfMetadataToHide);
	
	//@skip-warning
	MetadataCurrentRow = Undefined;
	Items.ObjectsListOptions.CurrentPage = Items.BlankPage;
	Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);

	UT_Common.ToolFormOnCreateAtServer(ThisObject, Cancel, StandardProcessing,
		Items.CommonCommandBar);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	If RegistrationObjectParameter <> Undefined Then
		// Opening another form
		Cancel = True;
		OpenForm(
			GetFormName() + "Form.ObjectRegistrationNodes",
			New Structure("RegistrationObject, RegistrationTable", RegistrationObjectParameter,
			RegistrationTableParameter));
	EndIf;

EndProcedure

&AtClient
Procedure OnClose(Exit)
	// Auto saving settings
	SavedInSettingsDataModified = Истина;
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Analyzing selected value, it must be a structure.
	If TypeOf(SelectedValue) <> Type("Structure") Or (Not SelectedValue.Property("ChoiceAction"))
		Or (Not SelectedValue.Property("ChoiceData")) Or TypeOf(SelectedValue.ChoiceAction) <> Type("Boolean")
		Or TypeOf(SelectedValue.ChoiceData) <> Type("String") Then
		Error = NStr("ru = 'Неожиданный результат выбора из консоли запросов'; en = 'Unexpected selection result received from the query console.'");
	Else
		Error = RefControlForQuerySelection(SelectedValue.ChoiceData);
	EndIf;

	If Error <> "" Then 
		ShowMessageBox(,Error);
		Return;
	EndIf;

	If SelectedValue.ChoiceAction Then
		Text = NStr("ru = 'Зарегистрировать результат запроса
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to register the query result
		                 |at node ""%1""?'"); 
	Else
		Text = NStr("ru = 'Отменить регистрацию результата запроса
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to cancel registration of the query result
		                 |at node ""%1""?'");
	EndIf;
	Text = StrReplace(Text, "%1", String(ExchangeNodeRef));
					 
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'");
	
	Notification = New NotifyDescription("ChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedValue", SelectedValue);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);

EndProcedure

Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ObjectDataExchangeRegistrationEdit" Then
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	ElsIf EventName = "ExchangeNodeDataEdit" And ExchangeNodeRef = Parameter Then
		SetMessageNumberTitle();		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	// Automatic settings
	CurrentObject = ThisObject();
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If RegistrationObjectParameter <> Undefined Then
		// Another form will be used.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.ExchangeNode) Then
		ExchangeNodeRef = Parameters.ExchangeNode;
	Else
		ExchangeNodeRef = Settings["ExchangeNodeRef"];
		/// If restored exchange node is deleted, clearing the ExchangeNodeRef value.
		//@skip-warning
		If ExchangeNodeRef <> Undefined And ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef))
		    And IsBlankString(ExchangeNodeRef.DataVersion) Then
			ExchangeNodeRef = Undefined;
		EndIf;
	EndIf;
	
	ControlSettings();
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEMS EVENT HANDLERS
//

&AtClient
Procedure ExchangeNodeRefStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CurFormName = GetFormName() + "Form.SelectExchangePlanNode";
	CurParameters = New Structure("MultipleChoice, ChoiceInitialValue", False, ExchangeNodeRef);
	OpenForm(CurFormName, CurParameters, Item);
EndProcedure

&AtClient
Procedure ExchangeNodeRefChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ExchangeNodeRef <> ValueSelected Then
		ExchangeNodeRef = ValueSelected;
		ExchangeNodeChoiceProcessing();
	EndIf;
EndProcedure

&AtClient
Procedure ExchangeNodeRefOnChange(Item)
	ExchangeNodeChoiceProcessing();
	ExpandMetadataTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ExchangeNodeRefClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FilterByMessageNumberOptionOnChange(Item)
	SetFilterByMessageNumber(ConstantsList, FilterByMessageNumberOption);
	SetFilterByMessageNumber(RefsList, FilterByMessageNumberOption);
	SetFilterByMessageNumber(RecordSetsList, FilterByMessageNumberOption);
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ObjectsListOptionsOnCurrentPageChange(Item, CurrentPage)
	UpdatePageContent(CurrentPage);
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// MetadataTree FORM TABLE ITEMS EVENT HANDLERS
//

&AtClient
Procedure MetadataTreeCheckOnChange(Item)
	ChangeMark(Items.MetadataTree.CurrentRow);
EndProcedure

&AtClient
Procedure MetadataTreeOnActivateRow(Item)
	If Items.MetadataTree.CurrentRow <> MetadataCurrentRow Then
		MetadataCurrentRow  = Items.MetadataTree.CurrentRow;
		AttachIdleHandler("SetUpChangeEditing", 0.0000001, True);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// ConstantsList FORM TABLE ITEMS EVENT HANDLERS
//

&AtClient
Procedure ConstantListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Result = AddRegistrationAtServer(True, ExchangeNodeRef, ValueSelected);
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
	ReportRegistrationResults(True, Result);

	If TypeOf(ValueSelected) = Type("Array") And ValueSelected.Count() > 0 Then
		Item.CurrentRow = ValueSelected[0];
	Else
		Item.CurrentRow = ValueSelected;
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// RefsList FORM TABLE ITEMS EVENT HANDLERS
//

&AtClient
Procedure ReferenceListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure
&AtClient
Procedure EditReference(Command)
	CurData=Items.RefsList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;

	UT_CommonClient.EditObject(CurData.Ref);
EndProcedure


////////////////////////////////////////////////////////////////////////////////////////////////////
// RecordSetsList FORM TABLE ITEMS EVENT HANDLERS
//

&AtClient
Procedure RecordSetListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	WriteParameters = RecordSetKeyStructure(Item.CurrentData);
	If WriteParameters <> Undefined Then
		OpenForm(WriteParameters.FormName, New Structure("Key", WriteParameters.Key));
	EndIf;

EndProcedure

&AtClient
Procedure RecordSetListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS
//

&AtClient
Procedure AddRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrPage = Items.ObjectsListOptions.CurrentPage;
	If CurrPage = Items.ConstantsPage Then
		AddConstantRegistrationInList();
	ElsIf CurrPage = Items.ReferencesListPage Then
		AddRegistrationToReferenceList();		
	ElsIf CurrPage = Items.RecordSetPage Then
		AddRegistrationToRecordSetFilter();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrPage = Items.ObjectsListOptions.CurrentPage;
	If CurrPage = Items.ConstantsPage Then
		DeleteConstantRegistrationInList();
	ElsIf CurrPage = Items.ReferencesListPage Then
		DeleteRegistrationFromReferenceList();
	ElsIf CurrPage = Items.RecordSetPage Then
		DeleteRegistrationInRecordSet();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrPage = Items.ObjectsListOptions.CurrentPage;
	If CurrPage = Items.ReferencesListPage Then
		AddRegistrationInListFilter();
	ElsIf CurrPage = Items.RecordSetPage Then
		AddRegistrationToRecordSetFilter();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrPage = Items.ObjectsListOptions.CurrentPage;
	If CurrPage = Items.ReferencesListPage Then
		DeleteRegistrationInListFilter();
	ElsIf CurrPage = Items.RecordSetPage Then
		DeleteRegistrationInRecordSetFilter();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenNodeRegistrationForm(Command)
	
	If SelectExchangeNodeProhibited Then
		Return;
	EndIf;
		
	Data = GetCurrentObjectToEdit();
	If Data <> Undefined Then
		RegistrationTable = ?(TypeOf(Data) = Type("Structure"), RecordSetsListTableName, "");
		OpenForm(GetFormName() + "Form.ObjectRegistrationNodes",
			New Structure("RegistrationObject, RegistrationTable, NotifyAboutChanges", Data, RegistrationTable, 
			True), ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExportResult(Command)
	
	CurPage = Items.ObjectsListOptions.CurrentPage;
	Serialization = New Array;
	
	If CurPage = Items.ConstantsPage Then 
		FormItem = Items.ConstantsList;
		For Each Row In FormItem.SelectedRows Do
			curData = FormItem.RowData(Row);
			Serialization.Add(New Structure("TypeFlag, Data", 1, curData.MetaFullName));
		EndDo;
		
	ElsIf CurPage = Items.RecordSetPage Then
		DimensionList = RecordSetKeyNameArray(RecordSetsListTableName);
		FormItem = Items.RecordSetsList;
		Prefix = "RecordSetsList";
		For Each Item In FormItem.SelectedRows Do
			curData = New Structure();
			Data = FormItem.RowData(Item);
			For Each Name In DimensionList Do
				curData.Insert(Name, Data[Prefix + Name]);
			EndDo;
			Serialization.Add(New Structure("TypeFlag, Data", 2, curData));
		EndDo;
		
	ElsIf CurPage = Items.ReferencesListPage Then
		FormItem = Items.RefsList;
		For Each Item In FormItem.SelectedRows Do
			curData = FormItem.RowData(Item);
			Serialization.Add(New Structure("TypeFlag, Data", 3, curData.Ref));
		EndDo;
		
	Else
		Return;
		
	EndIf;
	
	If Serialization.Count() > 0 Then
		Text = SerializationText(Serialization);
		TextTitle = NStr("ru = 'Результат стандартной выгрузки (РИБ)'; en = 'Standard export result (DIB)'");
		Text.Show(TextTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditMessagesNumbers(Command)
	
	If ValueIsFilled(ExchangeNodeRef) Then
		CurFormName = GetFormName() + "Form.ExchangePlanNodeMessageNumbers";
		CurParameters = New Structure("ExchangeNodeRef", ExchangeNodeRef);
		OpenForm(CurFormName, CurParameters);
	EndIf;
EndProcedure

&AtClient
Procedure AddConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddObjectDeletionRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationFromReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationPickup(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList(True);
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure AddRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationToRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure RefreshAllData(Command)
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure AddQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(True);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(False);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

&AtClient
Procedure EditObjectMessageNumber(Command)
	
	If Items.ObjectsListOptions.CurrentPage = Items.ConstantsPage Then
		EditConstantMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.ReferencesListPage Then
		EditRefMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.RecordSetPage Then
		EditMessageNoSetList()
		
	EndIf;
	
EndProcedure

//@skip-warning
&AtClient
Procedure Attachable_ExecuteToolsCommonCommand(Command) 
	UT_CommonClient.Attachable_ExecuteToolsCommonCommand(ThisObject, Command);
EndProcedure


////////////////////////////////////////////////////////////////////////////////////////////////////
// PRIVATE
//

&AtClient
Procedure ChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return
	EndIf;
	SelectedValue = AdditionalParameters.SelectedValue;

	ReportRegistrationResults(SelectedValue.ChoiceAction, ChangeQueryResultRegistrationServer(
		SelectedValue.ChoiceAction, SelectedValue.ChoiceData));

	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure EditConstantMessageNo()
	curData = Items.ConstantsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditConstantMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaFullName", curData.MetaFullName);
	
	MessageNumber = curData.MessageNo;
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of the last sent message'"); 
	
	ShowInputNumber(Notification, MessageNumber, Tooltip);
EndProcedure

&AtClient
Procedure EditConstantMessageNoCompletion(Val MessageNumber, Val AdditionalParameters) Export
	If MessageNumber = Undefined Then
		// Canceling input.
		Return;
	EndIf;

	ReportRegistrationResults(MessageNumber, EditMessageNumberAtServer(ExchangeNodeRef, MessageNumber,
		AdditionalParameters.MetaFullName));

	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditRefMessageNo()
	curData = Items.RefsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditRefMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Ref", curData.Ref);
	
	MessageNumber = curData.MessageNo;
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of the last sent message'"); 
	
	ShowInputNumber(Notification, MessageNumber, Tooltip);
EndProcedure

&AtClient
Procedure РедактироватьНомерСообщенияСсылкиЗавершение(Знач НомерСообщения, Знач ДополнительныеПараметры) Экспорт
	Если НомерСообщения = Неопределено Тогда
		// Отказ от ввода
		Возврат;
	КонецЕсли;

	СообщитьОРезультатахРегистрации(НомерСообщения, ИзменитьНомерСообщенияНаСервере(ExchangeNodeRef, НомерСообщения,
		ДополнительныеПараметры.Ссылка));

	Элементы.RefsList.Обновить();
	ЗаполнитьКоличествоРегистрацийВДереве();
EndProcedure

&AtClient
Procedure РедактироватьНомерСообщенияСписокНаборов()
	ТекДанные = Элементы.RecordSetsList.ТекущиеДанные;
	Если ТекДанные = Неопределено Тогда
		Возврат;
	КонецЕсли;

	Оповещение = Новый ОписаниеОповещения("РедактироватьНомерСообщенияСписокНаборовЗавершение", ЭтотОбъект,
		Новый Структура);

	ДанныеСтроки = Новый Структура;
	ИменаКлючей = МассивИменКлючейНабораЗаписей(RecordSetsListTableName);
	Для Каждого Имя Из ИменаКлючей Цикл
		ДанныеСтроки.Вставить(Имя, ТекДанные["RecordSetsList" + Имя]);
	КонецЦикла;

	Оповещение.ДополнительныеПараметры.Вставить("ДанныеСтроки", ДанныеСтроки);

	НомерСообщения = ТекДанные.НомерСообщения;
	Подсказка = НСтр("ru='Номер отправленного'");

	ПоказатьВводЧисла(Оповещение, НомерСообщения, Подсказка);
EndProcedure

&AtClient
Procedure РедактироватьНомерСообщенияСписокНаборовЗавершение(Знач НомерСообщения, Знач ДополнительныеПараметры) Экспорт
	Если НомерСообщения = Неопределено Тогда
		// Отказ от ввода
		Возврат;
	КонецЕсли;

	СообщитьОРезультатахРегистрации(НомерСообщения, ИзменитьНомерСообщенияНаСервере(
		ExchangeNodeRef, НомерСообщения, ДополнительныеПараметры.ДанныеСтроки, RecordSetsListTableName));

	Элементы.RecordSetsList.Обновить();
	ЗаполнитьКоличествоРегистрацийВДереве();
EndProcedure

&AtClient
Procedure НастроитьРедактированиеИзменений()
	НастроитьРедактированиеИзмененийСервер(MetadataCurrentRow);
EndProcedure

&AtClient
Procedure РазвернутьДеревоМетаданных()
	Для Каждого Строка Из MetadataTree.ПолучитьЭлементы() Цикл
		Элементы.MetadataTree.Развернуть( Строка.ПолучитьИдентификатор());
	КонецЦикла;
EndProcedure

&AtServer
Procedure УстановитьЗаголовокНомеровСообщений()

	Текст = НСтр("ru='№ сообщений: отпр. %1, прин. %2'");

	Данные = ПрочитатьНомераСообщений();
	Текст = СтрЗаменить(Текст, "%1", Формат(Данные.НомерОтправленного, "ЧДЦ=0; ЧН="));
	Текст = СтрЗаменить(Текст, "%2", Формат(Данные.НомерПринятого, "ЧДЦ=0; ЧН="));

	Элементы.FormEditMessageNumbers.Заголовок = Текст;
EndProcedure

&AtServer
Procedure ОбработкаВыбораУзлаОбмена()
	
	// Изменяем номера узлов в гиперссылке по редактированию
	УстановитьЗаголовокНомеровСообщений();
	
	// Обновляем дерево метаданных
	ПрочитатьДеревоМетаданных();
	ЗаполнитьКоличествоРегистрацийВДереве();
	
	// Обновляем активную страницу
	//@skip-warning
	ПоследняяАктивнаяКолонкаМетаданных = Неопределено;
	//@skip-warning
	ПоследняяАктивнаяСтрокаМетаданных  = Неопределено;
	Элементы.ObjectsListOptions.ТекущаяСтраница = Элементы.BlankPage;

EndProcedure

&AtClient
Procedure СообщитьОРезультатахРегистрации(Команда, Результаты)

	Если ТипЗнч(Команда) = Тип("Булево") Тогда
		Если Команда Тогда
			ЗаголовокПредупреждения = НСтр("ru='Регистрация изменений:'");
			ТекстПредупреждения = НСтр("ru='Зарегистрировано %1 изменений из %2
									   |на узле ""%0""'");
		Иначе
			ЗаголовокПредупреждения = НСтр("ru='Отмена регистрации:'");
			ТекстПредупреждения = НСтр("ru='Отменена регистрация %1 изменений 
									   |на узле ""%0"".'");
		КонецЕсли;
	Иначе
		ЗаголовокПредупреждения = НСтр("ru='Изменение номера сообщения:'");
		ТекстПредупреждения = НСтр("ru='Номер сообщения изменен на %3
								   |у %1 объекта(ов)'");
	КонецЕсли;

	ТекстПредупреждения = СтрЗаменить(ТекстПредупреждения, "%0", ExchangeNodeRef);
	ТекстПредупреждения = СтрЗаменить(ТекстПредупреждения, "%1", Формат(Результаты.Успешно, "ЧН="));
	ТекстПредупреждения = СтрЗаменить(ТекстПредупреждения, "%2", Формат(Результаты.Всего, "ЧН="));
	ТекстПредупреждения = СтрЗаменить(ТекстПредупреждения, "%3", Команда);

	Предупреждением = Результаты.Всего <> Результаты.Успешно;
	Если Предупреждением Тогда
		ОбновитьОтображениеДанных();
		ПоказатьПредупреждение( , ТекстПредупреждения, , ЗаголовокПредупреждения);
	Иначе
		ПоказатьОповещениеПользователя(ЗаголовокПредупреждения, ПолучитьНавигационнуюСсылку(ExchangeNodeRef),
			ТекстПредупреждения, Элементы.HiddenPictureInfo32.Картинка);
	КонецЕсли;
EndProcedure

&AtServer
Функция ПолучитьФормуВыбораРезультатаЗапроса()

	ТекущийОбъект = ЭтотОбъектОбработки();
	ТекущийОбъект.ПрочитатьНастройки();
	ЭтотОбъектОбработки(ТекущийОбъект);

	Проверка = ТекущийОбъект.ПроверитьКорректностьНастроек();
	ЭтотОбъектОбработки(ТекущийОбъект);
	Если Проверка.QueryExternalDataProcessorAddressSetting <> Неопределено Тогда
		Возврат Неопределено;
	ИначеЕсли ПустаяСтрока(ТекущийОбъект.QueryExternalDataProcessorAddressSetting) Тогда
		Возврат Неопределено;
	ИначеЕсли НРег(Прав(СокрЛП(ТекущийОбъект.QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Тогда
		Обработка = ВнешниеОбработки.Создать(ТекущийОбъект.QueryExternalDataProcessorAddressSetting);
		ИдентификаторФормы = ".ФормаОбъекта";
	Иначе
		Обработка = Обработки[ТекущийОбъект.QueryExternalDataProcessorAddressSetting].Создать();
		ИдентификаторФормы = ".Форма";
	КонецЕсли;

	Возврат Обработка.Метаданные().ПолноеИмя() + ИдентификаторФормы;
КонецФункции

&AtClient
Procedure ДобавитьРегистрациюКонстантыВСписке()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.ВыборКонстанты";
	ТекПараметры = Новый Структура("УзелОбмена, МассивИменМетаданных, МассивПредставлений, МассивАвторегистрации",
		ExchangeNodeRef, MetadataNamesStructure.Константы, MetadataPresentationsStructure.Константы,
		MetadataAutoRecordStructure.Константы);
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.ConstantsList);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюКонстантыВСписке()

	Элемент = Элементы.ConstantsList;

	СписокПредставлений = Новый Массив;
	СписокИмен          = Новый Массив;
	Для Каждого Строка Из Элемент.ВыделенныеСтроки Цикл
		Данные = Элемент.ДанныеСтроки(Строка);
		СписокПредставлений.Добавить(Данные.Наименование);
		СписокИмен.Добавить(Данные.МетаПолноеИмя);
	КонецЦикла;

	Колво = СписокИмен.Количество();
	Если Колво = 0 Тогда
		Возврат;
	ИначеЕсли Колво = 1 Тогда
		Текст = НСтр("ru='Отменить регистрацию ""%2""
					 |на узле ""%1""?'");
	Иначе
		Текст = НСтр("ru='Отменить регистрацию выбранных констант
					 |на узле ""%1""?'");
	КонецЕсли;
	Текст = СтрЗаменить(Текст, "%1", ExchangeNodeRef);
	Текст = СтрЗаменить(Текст, "%2", СписокПредставлений[0]);

	ЗаголовокВопроса = НСтр("ru='Подтверждение'");

	Оповещение = Новый ОписаниеОповещения("УдалитьРегистрациюКонстантыВСпискеЗавершение", ЭтотОбъект, Новый Структура);
	Оповещение.ДополнительныеПараметры.Вставить("СписокИмен", СписокИмен);

	ПоказатьВопрос(Оповещение, Текст, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюКонстантыВСпискеЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	СообщитьОРезультатахРегистрации(Ложь, УдалитьРегистрациюНаСервере(Истина, ExchangeNodeRef,
		ДополнительныеПараметры.СписокИмен));

	Элементы.ConstantsList.Обновить();
	ЗаполнитьКоличествоРегистрацийВДереве();
EndProcedure

&AtClient
Procedure ДобавитьРегистрациюВСписокСсылок(ЭтоПодбор = Ложь)
	ТекИмяФормы = ПолучитьИмяФормы(RefsList) + "ФормаВыбора";
	ТекПараметры = Новый Структура("РежимВыбора, МножественныйВыбор, ЗакрыватьПриВыборе, ВыборГруппИЭлементов", Истина,
		Истина, ЭтоПодбор, ИспользованиеГруппИЭлементов.ГруппыИЭлементы);
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.RefsList);
EndProcedure

&AtClient
Procedure ДобавитьРегистрациюУдаленияОбъектаВСписокСсылок()
	Ссылка = СсылкаДляУдаленияОбъекта();
	ОбработкаВыбораДанных(Элементы.RefsList, Ссылка);
EndProcedure

&AtServer
Функция СсылкаДляУдаленияОбъекта(Знач УникальныйИдентификатор = Неопределено)
	Описание = ЭтотОбъектОбработки().ХарактеристикиПоМетаданным(RefsList.ОсновнаяТаблица);
	Если УникальныйИдентификатор = Неопределено Тогда
		Возврат Описание.Менеджер.ПолучитьСсылку();
	КонецЕсли;
	Возврат Описание.Менеджер.ПолучитьСсылку(УникальныйИдентификатор);
КонецФункции

&AtClient
Procedure ДобавитьРегистрациюВСписокОтбор()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.ВыборОбъектовОтбором";
	ТекПараметры = Новый Структура("ДействиеВыбора, ИмяТаблицы", Истина, ОсновнаяТаблицаДинамическогоСписка(
		RefsList));
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.RefsList);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюВСпискеОтбор()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.ВыборОбъектовОтбором";
	ТекПараметры = Новый Структура("ДействиеВыбора, ИмяТаблицы", Ложь, ОсновнаяТаблицаДинамическогоСписка(RefsList));
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.RefsList);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюИзСпискаСсылок()

	Элемент = Элементы.RefsList;

	СписокУдаления = Новый Массив;
	Для Каждого Строка Из Элемент.ВыделенныеСтроки Цикл
		Данные = Элемент.ДанныеСтроки(Строка);
		СписокУдаления.Добавить(Данные.Ссылка);
	КонецЦикла;

	Колво = СписокУдаления.Количество();
	Если Колво = 0 Тогда
		Возврат;
	ИначеЕсли Колво = 1 Тогда
		Текст = НСтр("ru='Отменить регистрацию ""%2""
					 |на узле ""%1""?'");
	Иначе
		Текст = НСтр("ru='Отменить регистрацию выбранных объектов
					 |на узле ""%1""?'");
	КонецЕсли;
	Текст = СтрЗаменить(Текст, "%1", ExchangeNodeRef);
	Текст = СтрЗаменить(Текст, "%2", СписокУдаления[0]);

	ЗаголовокВопроса = НСтр("ru='Подтверждение'");

	Оповещение = Новый ОписаниеОповещения("УдалитьРегистрациюИзСпискаСсылокЗавершение", ЭтотОбъект, Новый Структура);
	Оповещение.ДополнительныеПараметры.Вставить("СписокУдаления", СписокУдаления);

	ПоказатьВопрос(Оповещение, Текст, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюИзСпискаСсылокЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	СообщитьОРезультатахРегистрации(Ложь, УдалитьРегистрациюНаСервере(Истина, ExchangeNodeRef,
		ДополнительныеПараметры.СписокУдаления));

	Элементы.RefsList.Обновить();
	ЗаполнитьКоличествоРегистрацийВДереве();
EndProcedure

&AtClient
Procedure ДобавитьРегистрациюВНаборЗаписейОтбор()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.ВыборОбъектовОтбором";
	ТекПараметры = Новый Структура("ДействиеВыбора, ИмяТаблицы", Истина, RecordSetsListTableName);
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.RecordSetsList);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюВНабореЗаписей()

	СтруктураДанных = "";
	ИменаКлючей = МассивИменКлючейНабораЗаписей(RecordSetsListTableName);
	Для Каждого Имя Из ИменаКлючей Цикл
		СтруктураДанных = СтруктураДанных + "," + Имя;
	КонецЦикла;
	СтруктураДанных = Сред(СтруктураДанных, 2);

	Данные = Новый Массив;
	Элемент = Элементы.RecordSetsList;
	Для Каждого Строка Из Элемент.ВыделенныеСтроки Цикл
		ТекДанные = Элемент.ДанныеСтроки(Строка);
		ДанныеСтроки = Новый Структура;
		Для Каждого Имя Из ИменаКлючей Цикл
			ДанныеСтроки.Вставить(Имя, ТекДанные["RecordSetsList" + Имя]);
		КонецЦикла;
		Данные.Добавить(ДанныеСтроки);
	КонецЦикла;

	Если Данные.Количество() = 0 Тогда
		Возврат;
	КонецЕсли;

	Выбор = Новый Структура("ИмяТаблицы, ДанныеВыбора, ДействиеВыбора, СтруктураПолей", RecordSetsListTableName,
		Данные, Ложь, СтруктураДанных);

	ОбработкаВыбораДанных(Элементы.RecordSetsList, Выбор);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюВНабореЗаписейОтбор()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.ВыборОбъектовОтбором";
	ТекПараметры = Новый Структура("ДействиеВыбора, ИмяТаблицы", Ложь, RecordSetsListTableName);
	ОткрытьФорму(ТекИмяФормы, ТекПараметры, Элементы.RecordSetsList);
EndProcedure

&AtClient
Procedure ДобавитьРегистрациюВыделенныхОбъектов(БезУчетаАвторегистрации = Истина)

	Данные = ПолучитьВыбранныеИменаМетаданных(БезУчетаАвторегистрации);
	Колво = Данные.МетаИмена.Количество();
	Если Колво = 0 Тогда
		// Текущая строка
		Данные = ПолучитьИменаМетаданныхТекущейСтроки(БезУчетаАвторегистрации);
	КонецЕсли;

	Текст = НСтр("ru='Зарегистрировать %1 для выгрузки на узле ""%2""?
				 |
				 |Изменение регистрации большого количества объектов может занять продолжительное время!'");

	Текст = СтрЗаменить(Текст, "%1", Данные.Описание);
	Текст = СтрЗаменить(Текст, "%2", ExchangeNodeRef);

	ЗаголовокВопроса = НСтр("ru='Подтверждение'");

	Оповещение = Новый ОписаниеОповещения("ДобавитьРегистрациюВыделенныхОбъектовЗавершение", ЭтотОбъект,
		Новый Структура);
	Оповещение.ДополнительныеПараметры.Вставить("МетаИмена", Данные.МетаИмена);
	Оповещение.ДополнительныеПараметры.Вставить("БезУчетаАвторегистрации", БезУчетаАвторегистрации);

	ПоказатьВопрос(Оповещение, Текст, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure ДобавитьРегистрациюВыделенныхОбъектовЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	Результат = ДобавитьРегистрациюНаСервере(ДополнительныеПараметры.БезУчетаАвторегистрации, ExchangeNodeRef,
		ДополнительныеПараметры.МетаИмена);

	ЗаполнитьКоличествоРегистрацийВДереве();
	ОбновитьСодержимоеСтраницы();
	СообщитьОРезультатахРегистрации(Истина, Результат);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюВыделенныхОбъектов(БезУчетаАвторегистрации = Истина)

	Данные = ПолучитьВыбранныеИменаМетаданных(БезУчетаАвторегистрации);
	Колво = Данные.МетаИмена.Количество();
	Если Колво = 0 Тогда
		Данные = ПолучитьИменаМетаданныхТекущейСтроки(БезУчетаАвторегистрации);
	КонецЕсли;

	Текст = НСтр("ru='Отменить регистрацию %1 для выгрузки на узле ""%2""?
				 |
				 |Изменение регистрации большого количества объектов может занять продолжительное время!'");

	ЗаголовокВопроса = НСтр("ru='Подтверждение'");

	Текст = СтрЗаменить(Текст, "%1", Данные.Описание);
	Текст = СтрЗаменить(Текст, "%2", ExchangeNodeRef);

	Оповещение = Новый ОписаниеОповещения("УдалитьРегистрациюВыделенныхОбъектовЗавершение", ЭтотОбъект, Новый Структура);
	Оповещение.ДополнительныеПараметры.Вставить("МетаИмена", Данные.МетаИмена);
	Оповещение.ДополнительныеПараметры.Вставить("БезУчетаАвторегистрации", БезУчетаАвторегистрации);

	ПоказатьВопрос(Оповещение, Текст, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure УдалитьРегистрациюВыделенныхОбъектовЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	СообщитьОРезультатахРегистрации(Ложь, УдалитьРегистрациюНаСервере(ДополнительныеПараметры.БезУчетаАвторегистрации,
		ExchangeNodeRef, ДополнительныеПараметры.МетаИмена));

	ЗаполнитьКоличествоРегистрацийВДереве();
	ОбновитьСодержимоеСтраницы();
EndProcedure

&AtClient
Procedure ОбработкаВыбораДанных(ТаблицаФормы, ВыбранноеЗначение)

	Ссылка = Неопределено;
	Тип    = ТипЗнч(ВыбранноеЗначение);

	Если Тип = Тип("Структура") Тогда
		ИмяТаблицы = ВыбранноеЗначение.ИмяТаблицы;
		Действие   = ВыбранноеЗначение.ДействиеВыбора;
		Данные     = ВыбранноеЗначение.ДанныеВыбора;
	Иначе
		ИмяТаблицы = Неопределено;
		Действие = Истина;
		Если Тип = Тип("Массив") Тогда
			Данные = ВыбранноеЗначение;
		Иначе
			Данные = Новый Массив;
			Данные.Добавить(ВыбранноеЗначение);
		КонецЕсли;

		Если Данные.Количество() = 1 Тогда
			Ссылка = Данные[0];
		КонецЕсли;
	КонецЕсли;

	Если Действие Тогда
		Результат = ДобавитьРегистрациюНаСервере(Истина, ExchangeNodeRef, Данные, ИмяТаблицы);

		ТаблицаФормы.Обновить();
		ЗаполнитьКоличествоРегистрацийВДереве();
		СообщитьОРезультатахРегистрации(Действие, Результат);

		ТаблицаФормы.ТекущаяСтрока = Ссылка;
		Возврат;
	КонецЕсли;

	Если Ссылка = Неопределено Тогда
		Текст = НСтр("ru='Отменить регистрацию выбранных объектов
					 |на узле ""%1?'");
	Иначе
		Текст = НСтр("ru='Отменить регистрацию ""%2""
					 |на узле ""%1?'");
	КонецЕсли;

	Текст = СтрЗаменить(Текст, "%1", ExchangeNodeRef);
	Текст = СтрЗаменить(Текст, "%2", Ссылка);

	ЗаголовокВопроса = НСтр("ru='Подтверждение'");

	Оповещение = Новый ОписаниеОповещения("ОбработкаВыбораДанныхЗавершение", ЭтотОбъект, Новый Структура);
	Оповещение.ДополнительныеПараметры.Вставить("Действие", Действие);
	Оповещение.ДополнительныеПараметры.Вставить("ТаблицаФормы", ТаблицаФормы);
	Оповещение.ДополнительныеПараметры.Вставить("Данные", Данные);
	Оповещение.ДополнительныеПараметры.Вставить("ИмяТаблицы", ИмяТаблицы);
	Оповещение.ДополнительныеПараметры.Вставить("Ссылка", Ссылка);

	ПоказатьВопрос(Оповещение, Текст, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure ОбработкаВыбораДанныхЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	Результат = УдалитьРегистрациюНаСервере(Истина, ExchangeNodeRef, ДополнительныеПараметры.Данные,
		ДополнительныеПараметры.ИмяТаблицы);

	ДополнительныеПараметры.ТаблицаФормы.Обновить();
	ЗаполнитьКоличествоРегистрацийВДереве();
	СообщитьОРезультатахРегистрации(ДополнительныеПараметры.Действие, Результат);

	ДополнительныеПараметры.ТаблицаФормы.ТекущаяСтрока = ДополнительныеПараметры.Ссылка;
EndProcedure

&AtServer
Procedure ОбновитьСодержимоеСтраницы(Страница = Неопределено)
	ТекСтр = ?(Страница = Неопределено, Элементы.ObjectsListOptions.ТекущаяСтраница, Страница);

	Если ТекСтр = Элементы.ReferencesListPage Тогда
		Элементы.RefsList.Обновить();

	ИначеЕсли ТекСтр = Элементы.ConstantsPage Тогда
		Элементы.ConstantsList.Обновить();

	ИначеЕсли ТекСтр = Элементы.RecordSetPage Тогда
		Элементы.RecordSetsList.Обновить();

	ИначеЕсли ТекСтр = Элементы.BlankPage Тогда
		Строка = Элементы.MetadataTree.ТекущаяСтрока;
		Если Строка <> Неопределено Тогда
			Данные = MetadataTree.НайтиПоИдентификатору(Строка);
			Если Данные <> Неопределено Тогда
				НастроитьПустуюСтраницу(Данные.Description, Данные.МетаПолноеИмя);
			КонецЕсли;
		КонецЕсли;
	КонецЕсли;
EndProcedure

&AtClient
Функция ПолучитьТекущийОбъектРедактирования()

	ТекСтр = Элементы.ObjectsListOptions.ТекущаяСтраница;

	Если ТекСтр = Элементы.ReferencesListPage Тогда
		Данные = Элементы.RefsList.ТекущиеДанные;
		Если Данные <> Неопределено Тогда
			Возврат Данные.Ссылка;
		КонецЕсли;

	ИначеЕсли ТекСтр = Элементы.ConstantsPage Тогда
		Данные = Элементы.ConstantsList.ТекущиеДанные;
		Если Данные <> Неопределено Тогда
			Возврат Данные.МетаПолноеИмя;
		КонецЕсли;

	ИначеЕсли ТекСтр = Элементы.RecordSetPage Тогда
		Данные = Элементы.RecordSetsList.ТекущиеДанные;
		Если Данные <> Неопределено Тогда
			Результат = Новый Структура;
			Измерения = МассивИменКлючейНабораЗаписей(RecordSetsListTableName);
			Для Каждого Имя Из Измерения Цикл
				Результат.Вставить(Имя, Данные["RecordSetsList" + Имя]);
			КонецЦикла;
		КонецЕсли;
		Возврат Результат;

	КонецЕсли;

	Возврат Неопределено;

КонецФункции

&AtClient
Procedure ОткрытьФормуНастроекОбработки()
	ТекИмяФормы = ПолучитьИмяФормы() + "Форма.Настройки";
	ОткрытьФорму(ТекИмяФормы, , ЭтотОбъект);
EndProcedure

&AtClient
Procedure ОперацияСРезультатамиЗапроса(КомандаОперации)

	ТекИмяФормы = ПолучитьФормуВыбораРезультатаЗапроса();
	Если ТекИмяФормы <> Неопределено Тогда
		// Открываем
		Если КомандаОперации Тогда
			Текст = НСтр("ru='Регистрация изменений результата запроса'");
		Иначе
			Текст = НСтр("ru='Отмена регистрации изменений результата запроса'");
		КонецЕсли;
		ОткрытьФорму(ТекИмяФормы, Новый Структура("Заголовок, ДействиеВыбора, РежимВыбора, ЗакрыватьПриВыборе, ",
			Текст, КомандаОперации, Истина, Ложь), ЭтотОбъект);
		Возврат;
	КонецЕсли;
	
	// Не настроено или что-то поломано, предлагаем выбрать
	ТекстВопроса = НСтр("ru='В настройках не указана обработка для выполнения запросов.
						|Настроить сейчас?'");

	ЗаголовокВопроса = НСтр("ru='Настройки'");

	Оповещение = Новый ОписаниеОповещения("ОперацияСРезультатамиЗапросаЗавершение", ЭтотОбъект);
	ПоказатьВопрос(Оповещение, ТекстВопроса, РежимДиалогаВопрос.ДаНет, , , ЗаголовокВопроса);
EndProcedure

&AtClient
Procedure ОперацияСРезультатамиЗапросаЗавершение(Знач РезультатВопроса, Знач ДополнительныеПараметры) Экспорт
	Если РезультатВопроса <> КодВозвратаДиалога.Да Тогда
		Возврат;
	КонецЕсли;

	ОткрытьФормуНастроекОбработки();
EndProcedure

&AtServer
Функция ЗакавычитьСтроку(Строка)
	Возврат СтрЗаменить(Строка, """", """""");
КонецФункции

&AtServer
Функция ЭтотОбъектОбработки(ТекущийОбъект = Неопределено)
	Если ТекущийОбъект = Неопределено Тогда
		Возврат РеквизитФормыВЗначение("Объект");
	КонецЕсли;
	ЗначениеВРеквизитФормы(ТекущийОбъект, "Объект");
	Возврат Неопределено;
КонецФункции

&AtServer
Функция ПолучитьИмяФормы(ТекущийОбъект = Неопределено)
	Возврат ЭтотОбъектОбработки().ПолучитьИмяФормы(ТекущийОбъект);
КонецФункции

&AtServer
Функция ОсновнаяТаблицаДинамическогоСписка(РеквизитФормы)
	Возврат РеквизитФормы.ОсновнаяТаблица;
КонецФункции

&AtServer
Procedure ИзменениеПометки(Строка)
	ЭлементДанных = MetadataTree.НайтиПоИдентификатору(Строка);
	ЭтотОбъектОбработки().ИзменениеПометки(ЭлементДанных);
EndProcedure

&AtServer
Procedure ПрочитатьДеревоМетаданных()
	Данные = ЭтотОбъектОбработки().СформироватьСтруктуруМетаданных(ExchangeNodeRef);
	
	// Удаляем строки, которые нельзя редактировать
	МетаДерево = Данные.Дерево;
	Для Каждого ЭлементСписка Из NamesOfMetadataToHide Цикл
		УдалитьСтрокиДереваЗначенийМетаданных(ЭлементСписка.Значение, МетаДерево.Строки);
	КонецЦикла;

	ЗначениеВРеквизитФормы(МетаДерево, "MetadataTree");
	MetadataAutoRecordStructure = Данные.СтруктураАвторегистрации;
	MetadataPresentationsStructure   = Данные.СтруктураПредставлений;
	MetadataNamesStructure            = Данные.СтруктураИмен;
EndProcedure

&AtServer
Procedure УдалитьСтрокиДереваЗначенийМетаданных(Знач МетаПолноеИмя, СтрокиДерева)
	Если ПустаяСтрока(МетаПолноеИмя) Тогда
		Возврат;
	КонецЕсли;
	
	// В текущем наборе
	Фильтр = Новый Структура("МетаПолноеИмя", МетаПолноеИмя);
	Для Каждого СтрокаУдаления Из СтрокиДерева.НайтиСтроки(Фильтр, Ложь) Цикл
		СтрокиДерева.Удалить(СтрокаУдаления);
	КонецЦикла;
	
	// И из оставшихся иерархически
	Для Каждого СтрокаДерева Из СтрокиДерева Цикл
		УдалитьСтрокиДереваЗначенийМетаданных(МетаПолноеИмя, СтрокаДерева.Строки);
	КонецЦикла;
EndProcedure

&AtServer
Procedure ФорматироватьКоличествоИзменений(Строка)
	Строка.ChangeCountString = Формат(Строка.КоличествоИзменений, "ЧН=") + " / " + Формат(
		Строка.КоличествоНеВыгруженных, "ЧН=");
EndProcedure

&AtServer
Procedure ЗаполнитьКоличествоРегистрацийВДереве()

	Данные = ЭтотОбъектОбработки().ПолучитьКоличествоИзменений(MetadataNamesStructure, ExchangeNodeRef);
	
	// Проставляем в дерево
	Фильтр = Новый Структура("МетаПолноеИмя, УзелОбмена", Неопределено, ExchangeNodeRef);
	Нули   = Новый Структура("КоличествоИзменений, КоличествоВыгруженных, КоличествоНеВыгруженных", 0, 0, 0);

	Для Каждого Корень Из MetadataTree.ПолучитьЭлементы() Цикл
		СуммаКорень = Новый Структура("КоличествоИзменений, КоличествоВыгруженных, КоличествоНеВыгруженных", 0, 0, 0);

		Для Каждого Группа Из Корень.ПолучитьЭлементы() Цикл
			СуммаГруппа = Новый Структура("КоличествоИзменений, КоличествоВыгруженных, КоличествоНеВыгруженных", 0, 0,
				0);

			СписокУзлов = Группа.ПолучитьЭлементы();
			Если СписокУзлов.Количество() = 0 И MetadataNamesStructure.Свойство(Группа.МетаПолноеИмя) Тогда
				// Коллекция узлов без узлов, просуммируем руками, авторегистрацию возьмем из структуры
				Для Каждого МетаИмя Из MetadataNamesStructure[Группа.МетаПолноеИмя] Цикл
					Фильтр.МетаПолноеИмя = МетаИмя;
					Найдено = Данные.НайтиСтроки(Фильтр);
					Если Найдено.Количество() > 0 Тогда
						Строка = Найдено[0];
						СуммаГруппа.КоличествоИзменений     = СуммаГруппа.КоличествоИзменений
							+ Строка.КоличествоИзменений;
						СуммаГруппа.КоличествоВыгруженных   = СуммаГруппа.КоличествоВыгруженных
							+ Строка.КоличествоВыгруженных;
						СуммаГруппа.КоличествоНеВыгруженных = СуммаГруппа.КоличествоНеВыгруженных
							+ Строка.КоличествоНеВыгруженных;
					КонецЕсли;
				КонецЦикла;

			Иначе
				// Считаем по каждому узлу
				Для Каждого Узел Из СписокУзлов Цикл
					Фильтр.МетаПолноеИмя = Узел.МетаПолноеИмя;
					Найдено = Данные.НайтиСтроки(Фильтр);
					Если Найдено.Количество() > 0 Тогда
						Строка = Найдено[0];
						ЗаполнитьЗначенияСвойств(Узел, Строка,
							"КоличествоИзменений, КоличествоВыгруженных, КоличествоНеВыгруженных");
						СуммаГруппа.КоличествоИзменений     = СуммаГруппа.КоличествоИзменений
							+ Строка.КоличествоИзменений;
						СуммаГруппа.КоличествоВыгруженных   = СуммаГруппа.КоличествоВыгруженных
							+ Строка.КоличествоВыгруженных;
						СуммаГруппа.КоличествоНеВыгруженных = СуммаГруппа.КоличествоНеВыгруженных
							+ Строка.КоличествоНеВыгруженных;
					Иначе
						ЗаполнитьЗначенияСвойств(Узел, Нули);
					КонецЕсли;

					ФорматироватьКоличествоИзменений(Узел);
				КонецЦикла;

			КонецЕсли;
			ЗаполнитьЗначенияСвойств(Группа, СуммаГруппа);

			СуммаКорень.КоличествоИзменений     = СуммаКорень.КоличествоИзменений + Группа.КоличествоИзменений;
			СуммаКорень.КоличествоВыгруженных   = СуммаКорень.КоличествоВыгруженных + Группа.КоличествоВыгруженных;
			СуммаКорень.КоличествоНеВыгруженных = СуммаКорень.КоличествоНеВыгруженных + Группа.КоличествоНеВыгруженных;

			ФорматироватьКоличествоИзменений(Группа);
		КонецЦикла;

		ЗаполнитьЗначенияСвойств(Корень, СуммаКорень);

		ФорматироватьКоличествоИзменений(Корень);
	КонецЦикла;

EndProcedure

&AtServer
Функция ИзменитьРегистрациюРезультатаЗапросаСервер(Команда, Адрес)

	Результат = ПолучитьИзВременногоХранилища(Адрес);
	Результат= Результат[Результат.ВГраница()];
	Данные = Результат.Выгрузить().ВыгрузитьКолонку("Ссылка");

	Если Команда Тогда
		Возврат ДобавитьРегистрациюНаСервере(Истина, ExchangeNodeRef, Данные);
	КонецЕсли;

	Возврат УдалитьРегистрациюНаСервере(Истина, ExchangeNodeRef, Данные);
КонецФункции

&AtServer
Функция КонтрольСсылокДляВыбораЗапросом(Адрес)

	Результат = ?(Адрес = Неопределено, Неопределено, ПолучитьИзВременногоХранилища(Адрес));
	Если ТипЗнч(Результат) = Тип("Массив") Тогда
		Результат = Результат[Результат.ВГраница()];
		Если Результат.Колонки.Найти("Ссылка") = Неопределено Тогда
			Возврат НСтр("ru='В последнем результате запроса отсутствует колонка ""Ссылка""'");
		КонецЕсли;
	Иначе
		Возврат НСтр("ru='Ошибка получения данных результата запроса'");
	КонецЕсли;

	Возврат "";
КонецФункции

&AtServer
Procedure НастроитьРедактированиеИзмененийСервер(ТекущаяСтрока)

	Данные = MetadataTree.НайтиПоИдентификатору(ТекущаяСтрока);
	Если Данные = Неопределено Тогда
		Возврат;
	КонецЕсли;

	ИмяТаблицы   = Данные.МетаПолноеИмя;
	Наименование = Данные.Description;
	ТекущийОбъект   = ЭтотОбъектОбработки();

	Если ПустаяСтрока(ИмяТаблицы) Тогда
		Мета = Неопределено;
	Иначе
		Мета = ТекущийОбъект.МетаданныеПоПолномуИмени(ИмяТаблицы);
	КонецЕсли;

	Если Мета = Неопределено Тогда
		НастроитьПустуюСтраницу(Наименование, ИмяТаблицы);
		НовСтраница = Элементы.BlankPage;

	ИначеЕсли Мета = Метаданные.Константы Тогда
		// Все константы системы
		НастроитьСписокКонстант();
		НовСтраница = Элементы.ConstantsPage;

	ИначеЕсли ТипЗнч(Мета) = Тип("КоллекцияОбъектовМетаданных") Тогда
		// Все справочники, документы, и т.п.
		НастроитьПустуюСтраницу(Наименование, ИмяТаблицы);
		НовСтраница = Элементы.BlankPage;

	ИначеЕсли Метаданные.Константы.Содержит(Мета) Тогда
		// Одиночная константа
		НастроитьСписокКонстант(ИмяТаблицы, Наименование);
		НовСтраница = Элементы.ConstantsPage;

	ИначеЕсли Метаданные.Справочники.Содержит(Мета) Или Метаданные.Документы.Содержит(Мета)
		Или Метаданные.ПланыВидовХарактеристик.Содержит(Мета) Или Метаданные.ПланыСчетов.Содержит(Мета)
		Или Метаданные.ПланыВидовРасчета.Содержит(Мета) Или Метаданные.БизнесПроцессы.Содержит(Мета)
		Или Метаданные.Задачи.Содержит(Мета) Тогда
		// Ссылочный тип
		НастроитьСписокСсылок(ИмяТаблицы, Наименование);
		НовСтраница = Элементы.ReferencesListPage;

	Иначе
		// Проверим на набор записей
		Измерения = ТекущийОбъект.ИзмеренияНабораЗаписей(ИмяТаблицы);
		Если Измерения <> Неопределено Тогда
			НастроитьНаборЗаписей(ИмяТаблицы, Измерения, Наименование);
			НовСтраница = Элементы.RecordSetPage;
		Иначе
			НастроитьПустуюСтраницу(Наименование, ИмяТаблицы);
			НовСтраница = Элементы.BlankPage;
		КонецЕсли;

	КонецЕсли;

	Элементы.ConstantsPage.Видимость    = Ложь;
	Элементы.ReferencesListPage.Видимость = Ложь;
	Элементы.RecordSetPage.Видимость = Ложь;
	Элементы.BlankPage.Видимость       = Ложь;

	Элементы.ObjectsListOptions.ТекущаяСтраница = НовСтраница;
	НовСтраница.Видимость = Истина;

	НастроитьВидимостьКомандОбщегоМеню();
EndProcedure

// Вывод изменений для ссылочного типа (cправочник, документ, план видов характеристик, 
// план счетов, вид расчета, бизнес-процессы, задачи)
//
&AtServer
Procedure НастроитьСписокСсылок(ИмяТаблицы, Наименование)

	RefsList.ТекстЗапроса = 
	"ВЫБРАТЬ
	|	ТаблицаИзменений.НомерСообщения КАК НомерСообщения,
	|	ТаблицаИзменений.Ссылка КАК Ссылка,
	|	ВЫБОР
	|		КОГДА ТаблицаИзменений.НомерСообщения ЕСТЬ NULL
	|			ТОГДА ИСТИНА
	|		ИНАЧЕ ЛОЖЬ
	|	КОНЕЦ КАК НеВыгружалось
	|ИЗ
	|	" + ИмяТаблицы + ".Изменения КАК ТаблицаИзменений
	|ГДЕ
	|	ТаблицаИзменений.Узел = &ВыбранныйУзел";	

	RefsList.Параметры.УстановитьЗначениеПараметра("ВыбранныйУзел", ExchangeNodeRef);
//	RefsList.ОсновнаяТаблица = ИмяТаблицы;
	RefsList.ДинамическоеСчитываниеДанных = Истина;
	
	// Представление объекта
	Мета = ЭтотОбъектОбработки().МетаданныеПоПолномуИмени(ИмяТаблицы);
	ТекЗаголовок = Мета.ПредставлениеОбъекта;
	Если ПустаяСтрока(ТекЗаголовок) Тогда
		ТекЗаголовок = Наименование;
	КонецЕсли;
	Элементы.RefsListRefPresentation.Заголовок = ТекЗаголовок;
EndProcedure

// Вывод изменений для констант
//
&AtServer
Procedure НастроитьСписокКонстант(ИмяТаблицы = Неопределено, Наименование = "")

	Если ИмяТаблицы = Неопределено Тогда
		// Все константы
		Имена = MetadataNamesStructure.Константы;
		Представления = MetadataPresentationsStructure.Константы;
		Авторегистрация = MetadataAutoRecordStructure.Константы;
	Иначе
		Имена = Новый Массив;
		Имена.Добавить(ИмяТаблицы);
		Представления = Новый Массив;
		Представления.Добавить(Наименование);
		Индекс = MetadataNamesStructure.Константы.Найти(ИмяТаблицы);
		Авторегистрация = Новый Массив;
		Авторегистрация.Добавить(MetadataAutoRecordStructure.Константы[Индекс]);
	КонецЕсли;
	
	// И помнить про ограничение на количество таблиц
	Текст = "";
	Для Индекс = 0 По Имена.ВГраница() Цикл
		Имя = Имена[Индекс];
		Текст = Текст + ?(Текст = "", "ВЫБРАТЬ", "ОБЪЕДИНИТЬ ВСЕ ВЫБРАТЬ") + "
																			 |	" + Формат(Авторегистрация[Индекс],
			"ЧН=; ЧГ=") + " КАК ИндексКартинкиАвторегистрация,
						  |	2                                                   КАК PictureIndex,
						  |
						  |	""" + ЗакавычитьСтроку(Представления[Индекс]) + """ КАК Description,
																			   |	""" + Имя
			+ """ КАК МетаПолноеИмя,
			  |
			  |	ТаблицаИзменений.НомерСообщения КАК НомерСообщения,
			  |	ВЫБОР 
			  |		КОГДА ТаблицаИзменений.НомерСообщения ЕСТЬ NULL ТОГДА ИСТИНА ИНАЧЕ ЛОЖЬ
			  |	КОНЕЦ КАК НеВыгружалось
			  |ИЗ
			  |	" + Имя + ".Изменения КАК ТаблицаИзменений
							 |ГДЕ
							 |	ТаблицаИзменений.Узел=&ВыбранныйУзел
							 |";
	КонецЦикла;

	ConstantsList.ТекстЗапроса = "
								  |ВЫБРАТЬ
								  |	ИндексКартинкиАвторегистрация, PictureIndex, МетаПолноеИмя, НеВыгружалось,
								  |	Description, НомерСообщения
								  |
								  |{ВЫБРАТЬ
								  |	ИндексКартинкиАвторегистрация, PictureIndex, 
								  |	Description, МетаПолноеИмя, 
								  |	НомерСообщения, НеВыгружалось
								  |}
								  |
								  |ИЗ (" + Текст + ") Данные
												   |
												   |{ГДЕ
												   |	Description, НомерСообщения, НеВыгружалось
												   |}
												   |";

	ЭлементыСписка = ConstantsList.Порядок.Элементы;
	Если ЭлементыСписка.Количество() = 0 Тогда
		Элемент = ЭлементыСписка.Добавить(Тип("ЭлементПорядкаКомпоновкиДанных"));
		Элемент.Поле = Новый ПолеКомпоновкиДанных("Description");
		Элемент.Использование = Истина;
	КонецЕсли;

	ConstantsList.Параметры.УстановитьЗначениеПараметра("ВыбранныйУзел", ExchangeNodeRef);
	ConstantsList.ДинамическоеСчитываниеДанных = Истина;
EndProcedure	

// Вывод заглушки с пустой страницей.
&AtServer
Procedure НастроитьПустуюСтраницу(Наименование, ИмяТаблицы = Неопределено)

	Если ИмяТаблицы = Неопределено Тогда
		ТекстКоличеств = "";
	Иначе
		Дерево = РеквизитФормыВЗначение("MetadataTree");
		Строка = Дерево.Строки.Найти(ИмяТаблицы, "МетаПолноеИмя", Истина);
		Если Строка <> Неопределено Тогда
			ТекстКоличеств = НСтр("ru='Зарегистрировано объектов: %1
								  |Выгружено объектов: %2
								  |Не выгружено объектов: %3
								  |'");

			ТекстКоличеств = СтрЗаменить(ТекстКоличеств, "%1", Формат(Строка.КоличествоИзменений, "ЧДЦ=0; ЧН="));
			ТекстКоличеств = СтрЗаменить(ТекстКоличеств, "%2", Формат(Строка.КоличествоВыгруженных, "ЧДЦ=0; ЧН="));
			ТекстКоличеств = СтрЗаменить(ТекстКоличеств, "%3", Формат(Строка.КоличествоНевыгруженных, "ЧДЦ=0; ЧН="));
		КонецЕсли;
	КонецЕсли;

	Текст = НСтр("ru='%1.
				 |
				 |%2
				 |Для регистрации или отмены регистрации обмена данными на узле
				 |""%3""
				 |выберите тип объекта слева в дереве метаданных и воспользуйтесь
				 |командами ""Зарегистрировать"" или ""Отменить регистрацию""'");

	Текст = СтрЗаменить(Текст, "%1", Наименование);
	Текст = СтрЗаменить(Текст, "%2", ТекстКоличеств);
	Текст = СтрЗаменить(Текст, "%3", ExchangeNodeRef);
	Элементы.BlankPageDecoration.Заголовок = Текст;
EndProcedure

// Вывод изменений для наборов записей
//
&AtServer
Procedure НастроитьНаборЗаписей(ИмяТаблицы, Измерения, Наименование)

	ТекстВыбора = "";
	Префикс     = "RecordSetsList";
	Для Каждого Строка Из Измерения Цикл
		Имя = Строка.Имя;
		ТекстВыбора = ТекстВыбора + ",ТаблицаИзменений." + Имя + " КАК " + Префикс + Имя + Символы.ПС;
		// Чтобы не наступить на измерение "НомерСообщения" или "НеВыгружалось"
		Строка.Имя = Префикс + Имя;
	КонецЦикла;

	RecordSetsList.ТекстЗапроса = "
										|ВЫБРАТЬ
										|	ТаблицаИзменений.НомерСообщения КАК НомерСообщения,
										|	ВЫБОР 
										|		КОГДА ТаблицаИзменений.НомерСообщения ЕСТЬ NULL ТОГДА ИСТИНА ИНАЧЕ ЛОЖЬ
										|	КОНЕЦ КАК НеВыгружалось
										|
										|	" + ТекстВыбора + "
															   |ИЗ
															   |	" + ИмяТаблицы + ".Изменения КАК ТаблицаИзменений
																					 |ГДЕ
																					 |	ТаблицаИзменений.Узел = &ВыбранныйУзел
																					 |";
	RecordSetsList.Параметры.УстановитьЗначениеПараметра("ВыбранныйУзел", ExchangeNodeRef);
	
	// Добавляем в группу измерений
	ЭтотОбъектОбработки().ДобавитьКолонкиВТаблицуФормы(
		Элементы.RecordSetsList, "НомерСообщения, НеВыгружалось, 
									   |Порядок, Отбор, Группировка, СтандартнаяКартинка, Параметры, УсловноеОформление",
		Измерения, Элементы.RecordSetsListDimensionsGroup);
	RecordSetsList.ДинамическоеСчитываниеДанных = Истина;
	RecordSetsListTableName = ИмяТаблицы;
EndProcedure

// Общий отбор по полю "НомерСообщения"
//
&AtServer
Procedure SetFilterByMessageNumber(ДинамоСписок, Вариант)

	Поле = Новый ПолеКомпоновкиДанных("НеВыгружалось");
	// Ищем свое поле, попутно отключаем все по нему
	ЭлементыСписка = ДинамоСписок.Отбор.Элементы;
	Индекс = ЭлементыСписка.Количество();
	Пока Индекс > 0 Цикл
		Индекс = Индекс - 1;
		Элемент = ЭлементыСписка[Индекс];
		Если Элемент.ЛевоеЗначение = Поле Тогда
			ЭлементыСписка.Удалить(Элемент);
		КонецЕсли;
	КонецЦикла;

	ЭлементОтбора = ЭлементыСписка.Добавить(Тип("ЭлементОтбораКомпоновкиДанных"));
	ЭлементОтбора.ЛевоеЗначение = Поле;
	ЭлементОтбора.ВидСравнения  = ВидСравненияКомпоновкиДанных.Равно;
	ЭлементОтбора.Использование = Ложь;
	ЭлементОтбора.РежимОтображения = РежимОтображенияЭлементаНастройкиКомпоновкиДанных.Недоступный;

	Если Вариант = 1 Тогда 		// Выгруженные
		ЭлементОтбора.ПравоеЗначение = Ложь;
		ЭлементОтбора.Использование  = Истина;

	ИначеЕсли Вариант = 2 Тогда	// Не выгруженные
		ЭлементОтбора.ПравоеЗначение = Истина;
		ЭлементОтбора.Использование  = Истина;

	КонецЕсли;

EndProcedure

&AtServer
Procedure НастроитьВидимостьКомандОбщегоМеню()

	ТекСтр = Элементы.ObjectsListOptions.ТекущаяСтраница;

	Если ТекСтр = Элементы.ConstantsPage Тогда
		Элементы.FormAddRegistrationForSingleObject.Доступность = Истина;
		Элементы.FormAddRegistrationFilter.Доступность         = Ложь;
		Элементы.FormDeleteRegistrationForSingleObject.Доступность  = Истина;
		Элементы.FormDeleteRegistrationFilter.Доступность          = Ложь;

	ИначеЕсли ТекСтр = Элементы.ReferencesListPage Тогда
		Элементы.FormAddRegistrationForSingleObject.Доступность = Истина;
		Элементы.FormAddRegistrationFilter.Доступность         = Истина;
		Элементы.FormDeleteRegistrationForSingleObject.Доступность  = Истина;
		Элементы.FormDeleteRegistrationFilter.Доступность          = Истина;

	ИначеЕсли ТекСтр = Элементы.RecordSetPage Тогда
		Элементы.FormAddRegistrationForSingleObject.Доступность = Истина;
		Элементы.FormAddRegistrationFilter.Доступность         = Ложь;
		Элементы.FormDeleteRegistrationForSingleObject.Доступность  = Истина;
		Элементы.FormDeleteRegistrationFilter.Доступность          = Ложь;

	Иначе
		Элементы.FormAddRegistrationForSingleObject.Доступность = Ложь;
		Элементы.FormAddRegistrationFilter.Доступность         = Ложь;
		Элементы.FormDeleteRegistrationForSingleObject.Доступность  = Ложь;
		Элементы.FormDeleteRegistrationFilter.Доступность          = Ложь;

	КонецЕсли;
EndProcedure

&AtServer
Функция МассивИменКлючейНабораЗаписей(ИмяТаблицы, ПрефиксИмен = "")
	Результат = Новый Массив;
	Измерения = ЭтотОбъектОбработки().ИзмеренияНабораЗаписей(ИмяТаблицы);
	Если Измерения <> Неопределено Тогда
		Для Каждого Строка Из Измерения Цикл
			Результат.Добавить(ПрефиксИмен + Строка.Имя);
		КонецЦикла;
	КонецЕсли;
	Возврат Результат;
КонецФункции

&AtServer
Функция МенеджерПоМетаданным(ИмяТаблицы)
	Описание = ЭтотОбъектОбработки().ХарактеристикиПоМетаданным(ИмяТаблицы);
	Если Описание <> Неопределено Тогда
		Возврат Описание.Менеджер;
	КонецЕсли;
	Возврат Неопределено;
КонецФункции

&AtServer
Функция ТекстСериализации(Сериализация)

	Текст = Новый ТекстовыйДокумент;

	Запись = Новый ЗаписьXML;
	Для Каждого Элемент Из Сериализация Цикл
		Запись.УстановитьСтроку("UTF-16");
		Значение = Неопределено;

		Если Элемент.ФлагТипа = 1 Тогда
			// Метаданные
			Менеджер = МенеджерПоМетаданным(Элемент.Данные);
			Значение = Менеджер.СоздатьМенеджерЗначения();

		ИначеЕсли Элемент.ФлагТипа = 2 Тогда
			// Набор данных с отбором
			Менеджер = МенеджерПоМетаданным(RecordSetsListTableName);
			Значение = Менеджер.СоздатьНаборЗаписей();
			Отбор = Значение.Отбор;
			Для Каждого ИмяЗначение Из Элемент.Данные Цикл
				Отбор[ИмяЗначение.Ключ].Установить(ИмяЗначение.Значение);
			КонецЦикла;
			Значение.Прочитать();

		ИначеЕсли Элемент.ФлагТипа = 3 Тогда
			// Ссылка
			Значение = Элемент.Данные.ПолучитьОбъект();
			Если Значение = Неопределено Тогда
				Значение = Новый УдалениеОбъекта(Элемент.Данные);
			КонецЕсли;
		КонецЕсли;

		ЗаписатьXML(Запись, Значение);
		Текст.ДобавитьСтроку(Запись.Закрыть());
	КонецЦикла;

	Возврат Текст;
КонецФункции

&AtServer
Функция УдалитьРегистрациюНаСервере(БезУчетаАвторегистрации, Узел, Удаляемые, ИмяТаблицы = Неопределено)
	Возврат ЭтотОбъектОбработки().ИзменитьРегистрациюНаСервере(Ложь, БезУчетаАвторегистрации, Узел, Удаляемые, ИмяТаблицы);
КонецФункции

&AtServer
Функция ДобавитьРегистрациюНаСервере(БезУчетаАвторегистрации, Узел, Добавляемые, ИмяТаблицы = Неопределено)
	Возврат ЭтотОбъектОбработки().ИзменитьРегистрациюНаСервере(Истина, БезУчетаАвторегистрации, Узел, Добавляемые, ИмяТаблицы);
КонецФункции

&AtServer
Функция ИзменитьНомерСообщенияНаСервере(Узел, НомерСообщения, Данные, ИмяТаблицы = Неопределено)
	Возврат ЭтотОбъектОбработки().ИзменитьРегистрациюНаСервере(НомерСообщения, Истина, Узел, Данные, ИмяТаблицы);
КонецФункции

&AtServer
Функция ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации, МетаИмяГруппа = Неопределено,
	МетаИмяУзел = Неопределено)

	Если МетаИмяГруппа = Неопределено И МетаИмяУзел = Неопределено Тогда
		// Не указано ничего
		Текст = НСтр("ru='все объекты %1 по выбранной иерархии вида'");

	ИначеЕсли МетаИмяГруппа <> Неопределено И МетаИмяУзел = Неопределено Тогда
		// Указана только группа, рассматриваем ее как Description группы
		Текст = "%2 %1";

	ИначеЕсли МетаИмяГруппа = Неопределено И МетаИмяУзел <> Неопределено Тогда
		// Указан только узел, рассматриваем как много выделенных объектов
		Текст = НСтр("ru='все объекты %1 по выбранной иерархии вида'");

	Иначе
		// Указаны и группа и узел, рассматриваем как имена метаданных
		Текст = НСтр("ru='все объекты типа ""%3"" %1'");

	КонецЕсли;

	Если БезУчетаАвторегистрации Тогда
		ТекстФлага = "";
	Иначе
		ТекстФлага = НСтр("ru='с признаком авторегистрации'");
	КонецЕсли;

	Представление = "";
	Для Каждого КлючЗначение Из MetadataPresentationsStructure Цикл
		Если КлючЗначение.Ключ = МетаИмяГруппа Тогда
			Индекс = MetadataNamesStructure[МетаИмяГруппа].Найти(МетаИмяУзел);
			Представление = ?(Индекс = Неопределено, "", КлючЗначение.Значение[Индекс]);
			Прервать;
		КонецЕсли;
	КонецЦикла;

	Текст = СтрЗаменить(Текст, "%1", ТекстФлага);
	Текст = СтрЗаменить(Текст, "%2", НРег(МетаИмяГруппа));
	Текст = СтрЗаменить(Текст, "%3", Представление);

	Возврат СокрЛП(Текст);
КонецФункции

&AtServer
Функция ПолучитьИменаМетаданныхТекущейСтроки(БезУчетаАвторегистрации)

	Строка = MetadataTree.НайтиПоИдентификатору(Элементы.MetadataTree.ТекущаяСтрока);
	Если Строка = Неопределено Тогда
		Возврат Неопределено;
	КонецЕсли;

	Результат = Новый Структура("МетаИмена, Описание", Новый Массив, ПолучитьОписаниеВыбранныхМетаданных(
		БезУчетаАвторегистрации));
	МетаИмя = Строка.МетаПолноеИмя;
	Если ПустаяСтрока(МетаИмя) Тогда
		Результат.МетаИмена.Добавить(Неопределено);
	Иначе
		Результат.МетаИмена.Добавить(МетаИмя);

		Родитель = Строка.ПолучитьРодителя();
		МетаРодительИмя = Родитель.МетаПолноеИмя;
		Если ПустаяСтрока(МетаРодительИмя) Тогда
			Результат.Описание = ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации, Строка.Description);
		Иначе
			Результат.Описание = ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации, МетаРодительИмя, МетаИмя);
		КонецЕсли;
	КонецЕсли;

	Возврат Результат;
КонецФункции

&AtServer
Функция ПолучитьВыбранныеИменаМетаданных(БезУчетаАвторегистрации)

	Результат = Новый Структура("МетаИмена, Описание", Новый Массив, ПолучитьОписаниеВыбранныхМетаданных(
		БезУчетаАвторегистрации));

	Для Каждого Корень Из MetadataTree.ПолучитьЭлементы() Цикл

		Если Корень.Check = 1 Тогда
			Результат.МетаИмена.Добавить(Неопределено);
			Возврат Результат;
		КонецЕсли;

		КолвоЧастичных = 0;
		КолвоГрупп     = 0;
		КолвоУзлов     = 0;
		Для Каждого Группа Из Корень.ПолучитьЭлементы() Цикл

			Если Группа.Check = 0 Тогда
				Продолжить;
			ИначеЕсли Группа.Check = 1 Тогда
				//	Весь группа целиком, смотрим откуда выбирать значения
				КолвоГрупп = КолвоГрупп + 1;
				ОписаниеГруппы = ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации, Группа.Наименование);

				Если Группа.ПолучитьЭлементы().Количество() = 0 Тогда
					// Пробуем из структуры имен метаданных, считаем все отмеченными
					//@skip-warning
					МассивПредставлений = MetadataPresentationsStructure[Группа.МетаПолноеИмя];
					МассивАвто          = MetadataAutoRecordStructure[Группа.МетаПолноеИмя];
					МассивИмен          = MetadataNamesStructure[Группа.МетаПолноеИмя];
					Для Индекс = 0 По МассивИмен.ВГраница() Цикл
						Если БезУчетаАвторегистрации Или МассивАвто[Индекс] = 2 Тогда
							Результат.МетаИмена.Добавить(МассивИмен[Индекс]);
							ОписаниеУзла = ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации,
								Группа.МетаПолноеИмя, МассивИмен[Индекс]);
						КонецЕсли;
					КонецЦикла;

					Продолжить;
				КонецЕсли;

			Иначе
				КолвоЧастичных = КолвоЧастичных + 1;
			КонецЕсли;

			Для Каждого Узел Из Группа.ПолучитьЭлементы() Цикл
				Если Узел.Check = 1 Тогда
					// Узел.AutoRegistration=2 -> разрешена
					Если БезУчетаАвторегистрации Или Узел.AutoRegistration = 2 Тогда
						Результат.МетаИмена.Добавить(Узел.МетаПолноеИмя);
						ОписаниеУзла = ПолучитьОписаниеВыбранныхМетаданных(БезУчетаАвторегистрации,
							Группа.МетаПолноеИмя, Узел.МетаПолноеИмя);
						КолвоУзлов = КолвоУзлов + 1;
					КонецЕсли;
				КонецЕсли;
			КонецЦикла
			;

		КонецЦикла;

		Если КолвоГрупп = 1 И КолвоЧастичных = 0 Тогда
			Результат.Описание = ОписаниеГруппы;
		ИначеЕсли КолвоГрупп = 0 И КолвоУзлов = 1 Тогда
			Результат.Описание = ОписаниеУзла;
		КонецЕсли;

	КонецЦикла;

	Возврат Результат;
КонецФункции

&AtServer
Функция ПрочитатьНомераСообщений()
	РеквизитыЗапроса = "НомерОтправленного, НомерПринятого";
	Данные = ЭтотОбъектОбработки().ПолучитьПараметрыУзлаОбмена(ExchangeNodeRef, РеквизитыЗапроса);
	Если Данные = Неопределено Тогда
		Возврат Новый Структура(РеквизитыЗапроса)
	КонецЕсли
	;
	Возврат Данные;
КонецФункции

&AtServer
Procedure ОбработатьЗапретИзмененияУзла()
	ОперацииРазрешены = Не SelectExchangeNodeProhibited;

	Если ОперацииРазрешены Тогда
		Элементы.ExchangeNodeRef.Видимость = Истина;
		Заголовок = НСтр("ru='Регистрация изменений для обмена данными'");
	Иначе
		Элементы.ExchangeNodeRef.Видимость = Ложь;
		Заголовок = СтрЗаменить(НСтр("ru='Регистрация изменений для обмена с  ""%1""'"), "%1", Строка(ExchangeNodeRef));
	КонецЕсли;

	Элементы.FormOpenNodeRegistrationForm.Видимость = ОперацииРазрешены;

	Элементы.ConstantsListContextMenuOpenNodeRegistrationForm.Видимость       = ОперацииРазрешены;
	Элементы.RefsListContextMenuOpenNodeRegistrationForm.Видимость         = ОперацииРазрешены;
	Элементы.RecordSetsListContextMenuOpenNodeRegistrationForm.Видимость = ОперацииРазрешены;
EndProcedure

&AtServer
Функция ПроконтролироватьНастройки()
	Результат = Истина;
	
	// Проверим на допустимость узла пришедшего из параметра или настроек
	ТекущийОбъект = ЭтотОбъектОбработки();
	Если ExchangeNodeRef <> Неопределено И ПланыОбмена.ТипВсеСсылки().СодержитТип(ТипЗнч(ExchangeNodeRef)) Тогда
		ДопустимыеУзлыОбмена = ТекущийОбъект.СформироватьДеревоУзлов();
		//@skip-warning
		ИмяПлана = ExchangeNodeRef.Метаданные().Имя;
		Если ДопустимыеУзлыОбмена.Строки.Найти(ИмяПлана, "ПланОбменаИмя", Истина) = Неопределено Тогда
			// Узел неверного плана обмена
			ExchangeNodeRef = Неопределено;
			Результат = Ложь;
		ИначеЕсли ExchangeNodeRef = ПланыОбмена[ИмяПлана].ЭтотУзел() Тогда
			// Этот узел
			ExchangeNodeRef = Неопределено;
			Результат = Ложь;
		КонецЕсли;
	КонецЕсли;

	Если ЗначениеЗаполнено(ExchangeNodeRef) Тогда
		ОбработкаВыбораУзлаОбмена();
	КонецЕсли;
	ОбработатьЗапретИзмененияУзла();
	
	// Зависимость настроек
	SetFilterByMessageNumber(ConstantsList, FilterByMessageNumberOption);
	SetFilterByMessageNumber(RefsList, FilterByMessageNumberOption);
	SetFilterByMessageNumber(RecordSetsList, FilterByMessageNumberOption);

	Возврат Результат;
КонецФункции

&AtServer
Функция СтруктураКлючаНабораЗаписей(Знач ТекущиеДанные)
	Описание  = ЭтотОбъектОбработки().ХарактеристикиПоМетаданным(RecordSetsListTableName);

	Если Описание = Неопределено Тогда
		// Неизвестный источник
		Возврат Неопределено;
	КонецЕсли;

	Результат = Новый Структура("Ключ, ИмяФормы");

	Измерения = Новый Структура;
	ИменаКлючей = МассивИменКлючейНабораЗаписей(RecordSetsListTableName);
	Для Каждого Имя Из ИменаКлючей Цикл
		Измерения.Вставить(Имя, ТекущиеДанные["RecordSetsList" + Имя]);
	КонецЦикла;

	Если Измерения.Свойство("Регистратор") Тогда
		МетаРегистратора = Метаданные.НайтиПоТипу(ТипЗнч(Измерения.Регистратор));
		Если МетаРегистратора = Неопределено Тогда
			Результат = Неопределено;
		Иначе
			Результат.ИмяФормы = МетаРегистратора.ПолноеИмя() + ".ФормаОбъекта";
			Результат.Ключ     = Измерения.Регистратор;
		КонецЕсли;
	ИначеЕсли Измерения.Количество() = 0 Тогда
		// Вырожденный набор записей
		Результат.ИмяФормы = RecordSetsListTableName + ".ФормаСписка";
	Иначе
		Результат.ИмяФормы = RecordSetsListTableName + ".ФормаЗаписи";
		Результат.Ключ     = Описание.Менеджер.СоздатьКлючЗаписи(Измерения);
	КонецЕсли;

	Возврат Результат;
КонецФункции