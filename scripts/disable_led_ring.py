#!/usr/bin/env python3
"""
Отключение LED кольца на ReSpeaker USB 4 Mic Array
Снижает энергопотребление и электромагнитные помехи
Особенно важно при использовании USB-изолятора B505S с ограниченным током
"""

import sys
import logging

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def disable_led_ring():
    """Отключить LED кольцо на ReSpeaker"""
    try:
        from pixel_ring import PixelRing
        p = PixelRing()
        p.off()
        logger.info("LED кольцо успешно отключено")
        return True
    except ImportError:
        logger.warning(
            "Библиотека pixel-ring не установлена. "
            "Установите: pip3 install pixel-ring"
        )
        logger.info("LED кольцо не будет отключено, но это не критично")
        return False
    except AttributeError as e:
        logger.warning(
            f"Модель ReSpeaker может не поддерживать LED кольцо через pixel-ring: {e}"
        )
        logger.info("Продолжаем работу без отключения LED")
        return False
    except Exception as e:
        # Если устройство не найдено или LED кольцо не поддерживается
        # - это не критичная ошибка
        error_msg = str(e).lower()
        if any(keyword in error_msg for keyword in ['not found', 'no device', 'no such', 'unsupported']):
            logger.info(f"LED кольцо не найдено или не поддерживается: {e}")
            logger.info("Это нормально для некоторых моделей ReSpeaker")
            return False
        else:
            logger.warning(f"Ошибка при отключении LED кольца: {e}")
            logger.info("Продолжаем работу без отключения LED")
            return False

if __name__ == "__main__":
    success = disable_led_ring()
    # Всегда возвращаем 0, чтобы не блокировать запуск respeaker-tune.sh
    # даже если LED кольцо не удалось отключить
    sys.exit(0)

