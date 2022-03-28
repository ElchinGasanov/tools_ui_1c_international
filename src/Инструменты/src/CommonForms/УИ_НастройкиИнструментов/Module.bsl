#Область ОбработчикиСобытийФормы

&НаСервере
Процедура ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	УстановитьСписокВыбораЭлементаИзСтруктуры(Элементы.РедакторКода1С,
		УИ_РедакторКодаКлиентСервер.ВариантыРедактораКода());
	
	РедакторКода1С = УИ_РедакторКодаСервер.ТекущийВариантРедактораКода1С();

	УстановитьСписокВыбораЭлементаИзСтруктуры(Элементы.ТемаРедактораMonaco,
		УИ_РедакторКодаКлиентСервер.ВариантыТемыРедактораMonaco());
	
	УстановитьСписокВыбораЭлементаИзСтруктуры(Элементы.ЯзыкСинтаксисаРедактораMonaco,
		УИ_РедакторКодаКлиентСервер.ВариантыЯзыкаСинтаксисаРедактораMonaco());

	ПараметрыРедактораMonaco = УИ_РедакторКодаСервер.ТекущиеПараметрыРедактораMonaco();
	
	ТемаРедактораMonaco = ПараметрыРедактораMonaco.Тема;
	ЯзыкСинтаксисаРедактораMonaco = ПараметрыРедактораMonaco.ЯзыкСинтаксиса;
	ИспользоватьКартуКода = ПараметрыРедактораMonaco.ИспользоватьКартуКода;
	СкрытьНомераСтрок = ПараметрыРедактораMonaco.СкрытьНомераСтрок;

	УстановитьВидимостьЭлементов();
КонецПроцедуры

&НаСервере
Процедура ОбработкаПроверкиЗаполненияНаСервере(Отказ, ПроверяемыеРеквизиты)

	ВариантыРедактораКода = УИ_РедакторКодаКлиентСервер.ВариантыРедактораКода();
	
	Если РедакторКода1С = ВариантыРедактораКода.Monaco Тогда
		ПроверяемыеРеквизиты.Добавить("ТемаРедактораMonaco");
		ПроверяемыеРеквизиты.Добавить("ЯзыкСинтаксисаРедактораMonaco");
	КонецЕсли;

КонецПроцедуры

#КонецОбласти

#Область ОбработчикиСобытийЭлементовШапкиФормы

&НаКлиенте
Процедура РедакторКода1СПриИзменении(Элемент)
	УстановитьВидимостьЭлементов();
КонецПроцедуры

#КонецОбласти


#Область ОбработчикиКомандФормы
&НаКлиенте
Процедура Применить(Команда)
	Если Не ПроверитьЗаполнение() Тогда
		Возврат;
	КонецЕсли;
	
	ПрименитьНаСервере();
	Закрыть();
КонецПроцедуры

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

&НаСервере
Процедура УстановитьВидимостьЭлементов()
	Варианты = УИ_РедакторКодаКлиентСервер.ВариантыРедактораКода();
	
	ЭтоМонако = РедакторКода1С = Варианты.Monaco;
	
	Элементы.ГруппаРедакторКодаMonaco.Видимость = ЭтоМонако;
КонецПроцедуры

&НаСервере
Процедура УстановитьСписокВыбораЭлементаИзСтруктуры(Элемент, СтруктураДанных)
	Элемент.СписокВыбора.Очистить();
	Для Каждого КлючЗначение ИЗ СтруктураДанных Цикл
		Элемент.СписокВыбора.Добавить(КлючЗначение.Ключ, КлючЗначение.Значение);
	КонецЦикла;		
	
КонецПроцедуры

&НаСервере
Процедура ПрименитьНаСервере()
	УИ_РедакторКодаСервер.УстановитьВариантРедактораКода1С(РедакторКода1С);
	
	ПараметрыРедактораMonaco = УИ_РедакторКодаКлиентСервер.ПараметрыРедактораMonacoПоУмолчанию();
	ПараметрыРедактораMonaco.Тема = ТемаРедактораMonaco;
	ПараметрыРедактораMonaco.ЯзыкСинтаксиса = ЯзыкСинтаксисаРедактораMonaco;
	ПараметрыРедактораMonaco.ИспользоватьКартуКода = ИспользоватьКартуКода;
	ПараметрыРедактораMonaco.СкрытьНомераСтрок = СкрытьНомераСтрок;
	УИ_РедакторКодаСервер.УстановитьНовыеПараметрыРедактораMonaco(ПараметрыРедактораMonaco);
	
КонецПроцедуры
#КонецОбласти