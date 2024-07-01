// Пример скрипта выполняющего проверку исходного кода

#Использовать osparser
#Использовать "./plugins"

// читаем исходный код, который хотим проверить.
ЧтениеТекста = Новый ЧтениеТекста("..\src\Классы\ПарсерВстроенногоЯзыка.os");
Исходник = ЧтениеТекста.Прочитать();
ЧтениеТекста.Закрыть();

// собираем нужные плагины в массив
Плагины = Новый Массив;
Плагины.Добавить(Новый ДетекторНеиспользуемыхПеременных);
Плагины.Добавить(Новый ДетекторОшибочныхЗамыкающихКомментариев);
Плагины.Добавить(Новый ДетекторФункцийБезВозвратаВКонце);

// Запуск проверки на данном исходном коде (Исходник) с желаемым набором плагинов (Плагины).
Парсер = Новый ПарсерВстроенногоЯзыка;
Парсер.Пуск(Исходник, Плагины);

// Выводим результаты работы плагинов.
Отчет = Новый Массив;
Для Каждого Ошибка Из Парсер.ТаблицаОшибок() Цикл
	Отчет.Добавить(Ошибка.Текст);
	Отчет.Добавить(СтрШаблон(" [стр: %1; кол: %2]", Ошибка.НомерСтрокиНачала, Ошибка.НомерКолонкиНачала));
	Отчет.Добавить(Символы.ПС);
КонецЦикла;
Сообщить(СтрСоединить(Отчет));