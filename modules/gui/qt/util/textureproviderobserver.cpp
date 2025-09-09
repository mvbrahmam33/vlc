/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "textureproviderobserver.hpp"

#include <QSGTextureProvider>

#if __has_include(<rhi/qrhi.h>) // RHI is semi-public since Qt 6.6
#define RHI_HEADER_AVAILABLE
#include <rhi/qrhi.h>
#endif

TextureProviderObserver::TextureProviderObserver(QObject *parent)
    : QObject{parent}
{

}

void TextureProviderObserver::setSource(const QQuickItem *source)
{
    if (m_source == source)
        return;

    {
        m_textureSize = QSize{}; // memory order does not matter, `setSource()` is not called frequently.

        if (m_source)
        {
            if (Q_LIKELY(m_provider))
            {
                disconnect(m_provider, nullptr, this, nullptr);
                m_provider = nullptr;
            }
            else
            {
                // source changed before we got its `QSGTextureProvider`
                disconnect(m_source, nullptr, this, nullptr);
            }
        }
    }

    m_source = source;

    if (m_source)
    {
        assert(m_source->isTextureProvider());

        const auto init = [this]() {
            const auto window = m_source->window();
            assert(window);

            connect(window, &QQuickWindow::beforeSynchronizing, this, [this, window]() {
                assert(m_source->window() == window);
                assert(!m_provider);

                m_provider = m_source->textureProvider(); // This can only be called in the rendering thread.
                assert(m_provider);

                connect(m_provider, &QSGTextureProvider::textureChanged, this, &TextureProviderObserver::updateTextureSize, Qt::DirectConnection);

                updateTextureSize();
            }, static_cast<Qt::ConnectionType>(Qt::SingleShotConnection | Qt::DirectConnection));
        };

        if (m_source->window())
            init();
        else
            connect(m_source, &QQuickItem::windowChanged, this, init, Qt::SingleShotConnection);
    }

    emit sourceChanged();
}

QSize TextureProviderObserver::textureSize() const
{
    // This is likely called in the QML/GUI thread.
    // QML/GUI thread can freely block the rendering thread to the extent the time is reasonable and a
    // fraction of `1/FPS`, because it is already throttled by v-sync (so it would just throttle less).
    return m_textureSize.load(std::memory_order_acquire);
}

QSize TextureProviderObserver::nativeTextureSize() const
{
    // This is likely called in the QML/GUI thread.
    // QML/GUI thread can freely block the rendering thread to the extent the time is reasonable and a
    // fraction of `1/FPS`, because it is already throttled by v-sync (so it would just throttle less).
    return m_nativeTextureSize.load(std::memory_order_acquire);
}

void TextureProviderObserver::updateTextureSize()
{
    // This is likely called in the rendering thread.
    // Rendering thread should avoid blocking the QML/GUI thread. In this case, unlike the high precision
    // timer case, it should be fine because the size may be inaccurate in the worst case until the next
    // frame when the size is sampled again. In high precision timer case, accuracy is favored over
    // potential stuttering.
    constexpr auto memoryOrder = std::memory_order_relaxed;

    if (m_provider)
    {
        if (const auto texture = m_provider->texture())
        {
            const auto textureSize = texture->textureSize();
            m_textureSize.store(textureSize, memoryOrder);

            {
                // Native texture size

                const auto legacyUpdateNativeTextureSize = [&]() {
                    const auto ntsr = texture->normalizedTextureSubRect();
                    m_nativeTextureSize.store({static_cast<int>(textureSize.width() / ntsr.width()),
                                               static_cast<int>(textureSize.height() / ntsr.height())},
                                              memoryOrder);
                };

#ifdef RHI_HEADER_AVAILABLE
                const QRhiTexture* const rhiTexture = texture->rhiTexture();
                if (Q_LIKELY(rhiTexture))
                    m_nativeTextureSize.store(rhiTexture->pixelSize(), memoryOrder);
                else
                    legacyUpdateNativeTextureSize();
#else
                legacyUpdateNativeTextureSize();
#endif
            }

            return;
        }
    }

    m_textureSize.store({}, memoryOrder);
}
