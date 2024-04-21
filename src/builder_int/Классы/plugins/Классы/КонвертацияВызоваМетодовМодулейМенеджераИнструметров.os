// BSLLS-off

// Этот плагин выполняет переименование переменных если это возможно.
// При возникновении конфликтов регистрирует ошибку, которая указывает на конфликтную переменную.

// Пример ожидаемой структуры параметров (json):
// {"СтароеИмя1": "НовоеИмя1", "СтароеИмя2": "НовоеИмя2"}

Перем Токены;
Перем Типы;
Перем ТаблицаОшибок;
Перем ТаблицаЗамен;
Перем Директивы;

Перем Результат;

Перем ПрефиксПеременныхИПроцедур;
Перем ОписаниеКонфигурации;
Перем МассивИменИнструментов;
Перем ТиповыеМетодыОбработок;

Процедура Открыть(Парсер, Параметры) Экспорт
	Типы = Парсер.Типы();
	ТаблицаОшибок = Парсер.ТаблицаОшибок();
	ТаблицаЗамен = Парсер.ТаблицаЗамен();
	Директивы = Парсер.Директивы();
	Токены = Парсер.Токены();
	
	Результат = Новый Массив;

	ПрефиксПеременныхИПроцедур=Параметры.ПрефиксПеременныхИПроцедур;
	ОписаниеКонфигурации=Параметры.ОписаниеКонфигурации;

	МассивИменИнструментов=Новый Массив;
	Для Каждого ТекОбъект Из ОписаниеКонфигурации.Обработки Цикл
		МассивИменИнструментов.Добавить(НРег(ТекОбъект.Имя));
	КонецЦикла;
	Для Каждого ТекОбъект Из ОписаниеКонфигурации.Отчеты Цикл
		МассивИменИнструментов.Добавить(НРег(ТекОбъект.Имя));
	КонецЦикла;

	ТиповыеМетодыОбработок=Новый Массив;
	ТиповыеМетодыОбработок.Добавить("получитьмакет");
	ТиповыеМетодыОбработок.Добавить("создать");
КонецПроцедуры // Открыть()

Функция Закрыть() Экспорт
	Возврат СтрСоединить(Результат);
КонецФункции // Закрыть()

Функция Подписки() Экспорт
	Перем Подписки;
	Подписки = Новый Массив;
	Подписки.Добавить("ПосетитьВыражениеИдентификатор");
	Возврат Подписки;
КонецФункции // Подписки()

#Область РеализацияПодписок

Процедура ПосетитьВыражениеИдентификатор(Описание) Экспорт
	Если НРег(Описание.Голова.Имя)="обработки" Тогда
		ЭтоОбработка=Истина;
	ИначеЕсли НРег(Описание.Голова.Имя)="отчеты" Тогда
		ЭтоОбработка=Ложь;
	Иначе
		Возврат;
	КонецЕсли;

	Если Описание.Хвост.Количество()<1 Тогда
		Возврат;
	КонецЕсли;

	ЭлементИмени=Описание.Хвост[0];
	Если ЭлементИмени.Тип<>Типы.ВыражениеПоле Тогда
		Возврат;
	КонецЕсли;

	Если МассивИменИнструментов.Найти(НРег(ЭлементИмени.Имя))=Неопределено Тогда
		Возврат;
	КонецЕсли;

	Если Описание.Хвост.Количество()<2 Тогда
		Замена(ПрефиксПеременныхИПроцедур+"CommonModulesByName("""+ЭлементИмени.Имя+"_ManagerModule"")",  Описание.Начало, ЭлементИмени.Конец);
		Возврат;
	КонецЕсли;

	ЭлементМетода=Описание.Хвост[1];
	Если ЭлементМетода.Тип<>Типы.ВыражениеПоле Тогда
		Возврат;
	КонецЕсли;

	Если ТиповыеМетодыОбработок.Найти(НРег(ЭлементМетода.Имя))=Неопределено Тогда
		Замена(ПрефиксПеременныхИПроцедур+"CommonModulesByName("""+ЭлементИмени.Имя+"_ManagerModule"")",  Описание.Начало, ЭлементИмени.Конец);
	ИначеЕсли НРег(ЭлементМетода.Имя)="создать" Тогда
		Замена(ПрефиксПеременныхИПроцедур+"CommonModulesByName("""+ЭлементИмени.Имя+""")",  Описание.Начало, ЭлементМетода.Конец);
	Иначе
		Замена("ВнешниеОбработки.Создать("""+ЭлементИмени.Имя+""")", Описание.Начало, ЭлементИмени.Конец);
	КонецЕсли;
КонецПроцедуры

#КонецОбласти // РеализацияПодписок

Процедура Ошибка(Текст, Начало, Конец = Неопределено, ЕстьЗамена = Ложь)
	Ошибка = ТаблицаОшибок.Добавить();
	Ошибка.Источник = "КонвертацияВызоваМетодовМодулейМенеджераИнструметров";
	Ошибка.Текст = Текст;
	Ошибка.ПозицияНачала = Начало.Позиция;
	Ошибка.НомерСтрокиНачала = Начало.НомерСтроки;
	Ошибка.НомерКолонкиНачала = Начало.НомерКолонки;
	Если Конец = Неопределено Или Конец = Начало Тогда
		Ошибка.ПозицияКонца = Начало.Позиция + Начало.Длина;
		Ошибка.НомерСтрокиКонца = Начало.НомерСтроки;
		Ошибка.НомерКолонкиКонца = Начало.НомерКолонки + Начало.Длина;
	Иначе
		Ошибка.ПозицияКонца = Конец.Позиция + Конец.Длина;
		Ошибка.НомерСтрокиКонца = Конец.НомерСтроки;
		Ошибка.НомерКолонкиКонца = Конец.НомерКолонки + Конец.Длина;
	КонецЕсли;
	Ошибка.ЕстьЗамена = ЕстьЗамена;
КонецПроцедуры

Процедура Замена(Текст, Начало, Конец = Неопределено)
	НоваяЗамена = ТаблицаЗамен.Добавить();
	НоваяЗамена.Источник = "КонвертацияВызоваМетодовМодулейМенеджераИнструметров";
	НоваяЗамена.Текст = Текст;
	НоваяЗамена.Позиция = Начало.Позиция;
	Если Конец = Неопределено Тогда
		НоваяЗамена.Длина = Начало.Длина;
	Иначе
		НоваяЗамена.Длина = Конец.Позиция + Конец.Длина - Начало.Позиция;
	КонецЕсли;
КонецПроцедуры

Процедура Вставка(Текст, Позиция)
	НоваяЗамена = ТаблицаЗамен.Добавить();
	НоваяЗамена.Источник = "КонвертацияВызоваМетодовМодулейМенеджераИнструметров";
	НоваяЗамена.Текст = Текст;
	НоваяЗамена.Позиция = Позиция;
	НоваяЗамена.Длина = 0;
КонецПроцедуры