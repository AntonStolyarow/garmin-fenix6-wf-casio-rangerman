import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Циферблат в стиле LCD: дата и день недели сверху,
// крупное время в блоке между двумя линиями, секунды снизу.
// Все символы рисуются примитивами (прямоугольники и многоугольники), без файлов шрифтов.
class LcdBlockView extends WatchUi.WatchFace {

    // Цвета. У Fenix 6 экран MIP на 64 цвета, поэтому только "чистые" значения
    private const BG = 0xFFFFFF;
    private const FG = 0x000000;
    private const LINE = 0x555555;

    // ---------- раскладка (экран 260x260, те же числа в tools/preview.py) ----------

    // Верхняя строка: месяц / день  день недели
    private const DATE_X = 51;
    private const DATE_Y = 52;
    private const DATE_W = 15;
    private const DATE_H = 26;
    private const DATE_T = 4;
    private const DATE_STEP = 20;
    private const SLASH_T = 2.5;    // толщина косой черты в дате

    // Линии, ограничивающие блок времени
    private const LINE1_Y = 89;
    private const LINE2_Y = 179;

    // Индикатор "P" (после полудня, только в 12-часовом режиме)
    private const P_X = 30;
    private const P_Y = 104;
    private const P_W = 12;
    private const P_H = 18;
    private const P_T = 4;

    // Время
    private const TIME_X = 48;
    private const MIN_X = 146;
    private const TIME_Y = 102;
    private const TIME_W = 36;
    private const TIME_H = 66;
    private const TIME_T = 9;
    private const TIME_STEP = 42;

    // Секунды
    private const SEC_X = 148;
    private const SEC_Y = 192;
    private const SEC_W = 24;
    private const SEC_H = 40;
    private const SEC_T = 6;
    private const SEC_STEP = 30;

    private var _days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    // Символы как наборы штрихов. Каждый штрих - 4 числа: x1, y1, x2, y2.
    // Коды по x: 0 - левый край, 1 - центр, 2 - правый край, 3 - правый край минус скос
    // Коды по y: 0 - верх, 1 - середина, 2 - низ, 3 - верх плюс скос, 4 - низ минус скос
    // Горизонтальные и вертикальные штрихи - прямоугольники, остальные - наклонные.
    private var _glyphs = {
        "0" => [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2],
        "1" => [2,0,2,2],
        "2" => [0,0,2,0, 2,0,2,1, 0,1,2,1, 0,1,0,2, 0,2,2,2],
        "3" => [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,1,2,1],
        "4" => [0,0,0,1, 0,1,2,1, 2,0,2,2],
        "5" => [0,0,2,0, 0,0,0,1, 0,1,2,1, 2,1,2,2, 0,2,2,2],
        "6" => [0,0,2,0, 0,0,0,2, 0,2,2,2, 2,1,2,2, 0,1,2,1],
        "7" => [0,0,2,0, 2,0,2,2],
        "8" => [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2, 0,1,2,1],
        "9" => [0,1,2,1, 0,0,0,1, 0,0,2,0, 2,0,2,2, 0,2,2,2],
        "A" => [0,0,0,2, 0,0,2,0, 2,0,2,2, 0,1,2,1],
        "D" => [0,0,3,0, 3,0,2,3, 2,3,2,4, 2,4,3,2, 0,2,3,2, 0,0,0,2],
        "E" => [0,0,2,0, 0,0,0,2, 0,2,2,2, 0,1,2,1],
        "F" => [0,0,2,0, 0,0,0,2, 0,1,2,1],
        "H" => [0,0,0,2, 2,0,2,2, 0,1,2,1],
        "I" => [1,0,1,2],
        "M" => [0,0,0,2, 0,0,2,0, 2,0,2,2, 1,0,1,1],
        "N" => [0,0,0,2, 0,0,2,0, 2,0,2,2],
        "O" => [0,0,2,0, 2,0,2,2, 0,2,2,2, 0,0,0,2],
        "P" => [0,0,0,2, 0,0,2,0, 2,0,2,1, 0,1,2,1],
        "R" => [0,0,0,2, 0,0,2,0, 2,0,2,1, 0,1,2,1, 1,1,2,2],
        "S" => [0,0,2,0, 0,0,0,1, 0,1,2,1, 2,1,2,2, 0,2,2,2],
        "T" => [0,0,2,0, 1,0,1,2],
        "U" => [0,0,0,2, 0,2,2,2, 2,0,2,2],
        "W" => [0,0,0,2, 0,2,2,2, 2,0,2,2, 1,1,1,2]
    };

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        dc.clearClip();
        dc.setColor(FG, BG);
        dc.clear();

        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hour = clock.hour;
        var pm = hour >= 12;
        if (!is24) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }

        // Линии блока времени
        dc.setColor(LINE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(24, LINE1_Y, 212, 2);
        dc.fillRectangle(28, LINE2_Y, 204, 2);

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);

        // Дата: "10/29 THU"
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawString(dc, pad(info.month), DATE_X, DATE_Y, DATE_W, DATE_H, DATE_T, DATE_STEP);
        drawThick(dc, DATE_X + 42, DATE_Y + 24, DATE_X + 50, DATE_Y + 2, SLASH_T);
        drawString(dc, pad(info.day), DATE_X + 54, DATE_Y, DATE_W, DATE_H, DATE_T, DATE_STEP);
        drawString(dc, _days[info.day_of_week - 1], DATE_X + 104, DATE_Y, DATE_W, DATE_H, DATE_T, DATE_STEP);

        // "P" после полудня в 12-часовом режиме
        if (!is24 && pm) {
            drawString(dc, "P", P_X, P_Y, P_W, P_H, P_T, 0);
        }

        // Время с двоеточием
        drawString(dc, pad(hour), TIME_X, TIME_Y, TIME_W, TIME_H, TIME_T, TIME_STEP);
        dc.fillRectangle(131, 119, 8, 8);
        dc.fillRectangle(131, 143, 8, 8);
        drawString(dc, clock.min.format("%02d"), MIN_X, TIME_Y, TIME_W, TIME_H, TIME_T, TIME_STEP);

        drawSeconds(dc, clock.sec);
    }

    // Вызывается раз в секунду в режиме сна: перерисовываем только секунды
    function onPartialUpdate(dc) {
        dc.setClip(SEC_X, SEC_Y, SEC_STEP + SEC_W, SEC_H);
        dc.setColor(BG, BG);
        dc.fillRectangle(SEC_X, SEC_Y, SEC_STEP + SEC_W, SEC_H);
        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        drawSeconds(dc, System.getClockTime().sec);
        dc.clearClip();
    }

    function onEnterSleep() {
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        WatchUi.requestUpdate();
    }

    // ---------- рисование ----------

    private function drawSeconds(dc, sec) {
        drawString(dc, sec.format("%02d"), SEC_X, SEC_Y, SEC_W, SEC_H, SEC_T, SEC_STEP);
    }

    // Строка символов слева направо с шагом step. Пробел и неизвестные символы пропускаются
    private function drawString(dc, text, x, y, w, h, t, step) {
        for (var i = 0; i < text.length(); i++) {
            var seg = _glyphs.get(text.substring(i, i + 1));
            if (seg != null) {
                drawGlyph(dc, seg, x + i * step, y, w, h, t);
            }
        }
    }

    // Один символ в рамке w x h, толщина штриха t.
    // Координаты в xs/ys - левый верхний угол квадрата t x t на концах штриха
    private function drawGlyph(dc, seg, x, y, w, h, t) {
        var q = (w - t) * 3 / 10;
        var xs = [x, x + (w - t) / 2, x + w - t, x + w - t - q];
        var ys = [y, y + (h - t) / 2, y + h - t, y + q, y + h - t - q];
        var r = t / 3;
        if (r < 1) {
            r = 1;
        }

        for (var i = 0; i < seg.size(); i += 4) {
            var x1 = xs[seg[i]];
            var y1 = ys[seg[i + 1]];
            var x2 = xs[seg[i + 2]];
            var y2 = ys[seg[i + 3]];

            if (x1 == x2 || y1 == y2) {
                var rx = (x1 < x2) ? x1 : x2;
                var ry = (y1 < y2) ? y1 : y2;
                var rw = ((x1 < x2) ? x2 - x1 : x1 - x2) + t;
                var rh = ((y1 < y2) ? y2 - y1 : y1 - y2) + t;
                dc.fillRoundedRectangle(rx, ry, rw, rh, r);
            } else {
                // Наклонный штрих от центра до центра концевых квадратов, концы закрываем квадратами
                drawThick(dc, x1 + t / 2.0, y1 + t / 2.0, x2 + t / 2.0, y2 + t / 2.0, t);
                dc.fillRectangle(x1, y1, t, t);
                dc.fillRectangle(x2, y2, t, t);
            }
        }
    }

    // Толстая линия толщиной t как четырёхугольник
    private function drawThick(dc, x1, y1, x2, y2, t) {
        var dx = (x2 - x1).toFloat();
        var dy = (y2 - y1).toFloat();
        var len = Math.sqrt(dx * dx + dy * dy);
        var nx = -dy / len * t / 2.0;
        var ny = dx / len * t / 2.0;
        dc.fillPolygon([
            [round(x1 + nx), round(y1 + ny)],
            [round(x2 + nx), round(y2 + ny)],
            [round(x2 - nx), round(y2 - ny)],
            [round(x1 - nx), round(y1 - ny)]
        ]);
    }

    private function round(v) {
        return (v + 0.5).toNumber();
    }

    // Число до двух знаков, ведущий ноль заменяется пробелом (как на LCD-часах)
    private function pad(n) {
        return (n < 10) ? " " + n.format("%d") : n.format("%d");
    }
}
