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
    """Отключить LED кольцо на ReSpeaker (USB и GPIO версии)"""
    try:
        # Используем автоопределение версии (USB или GPIO)
        from pixel_ring import pixel_ring
        
        # Проверяем что pixel_ring инициализирован
        if pixel_ring is None:
            logger.info("LED кольцо не найдено (pixel_ring is None)")
            return False
        
        # Отключаем LED
        pixel_ring.off()
        logger.info(f"LED кольцо успешно отключено (тип: {type(pixel_ring).__name__})")
        return True
        
    except ImportError:
        logger.warning(
            "Библиотека pixel-ring не установлена. "
            "Установите: pip3 install pixel-ring"
        )
        logger.info("LED кольцо не будет отключено, но это не критично")
        return False
    except Exception as e:
        # Любая ошибка - не критична
        error_msg = str(e).lower()
        if any(keyword in error_msg for keyword in ['not found', 'no device', 'no such', 'unsupported']):
            logger.info(f"LED кольцо не найдено или не поддерживается: {e}")
        else:
            logger.warning(f"Ошибка при отключении LED кольца: {e}")
        logger.info("Продолжаем работу без отключения LED")
        return False

if __name__ == "__main__":
    success = disable_led_ring()
    # Всегда возвращаем 0, чтобы не блокировать запуск respeaker-tune.sh
    # даже если LED кольцо не удалось отключить
    sys.exit(0)

