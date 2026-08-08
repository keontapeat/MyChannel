package com.mychannel.di

import com.mychannel.data.repository.AuthRepositoryImpl
import com.mychannel.data.repository.ChannelRepositoryImpl
import com.mychannel.data.repository.MusicRepositoryImpl
import com.mychannel.data.repository.NotificationRepositoryImpl
import com.mychannel.data.repository.PlaybackSessionRepositoryImpl
import com.mychannel.data.repository.SearchRepositoryImpl
import com.mychannel.data.repository.VideoRepositoryImpl
import com.mychannel.data.repository.VSMatchRepositoryImpl
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.ChannelRepository
import com.mychannel.domain.repository.MusicRepository
import com.mychannel.domain.repository.NotificationRepository
import com.mychannel.domain.repository.PlaybackSessionRepository
import com.mychannel.domain.repository.SearchRepository
import com.mychannel.domain.repository.VideoRepository
import com.mychannel.domain.repository.VSMatchRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module binding repository interfaces to their implementations.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(impl: AuthRepositoryImpl): AuthRepository

    @Binds
    @Singleton
    abstract fun bindVideoRepository(impl: VideoRepositoryImpl): VideoRepository

    @Binds
    @Singleton
    abstract fun bindPlaybackSessionRepository(
        impl: PlaybackSessionRepositoryImpl
    ): PlaybackSessionRepository

    @Binds
    @Singleton
    abstract fun bindChannelRepository(impl: ChannelRepositoryImpl): ChannelRepository

    @Binds
    @Singleton
    abstract fun bindSearchRepository(impl: SearchRepositoryImpl): SearchRepository

    @Binds
    @Singleton
    abstract fun bindVSMatchRepository(impl: VSMatchRepositoryImpl): VSMatchRepository

    @Binds
    @Singleton
    abstract fun bindMusicRepository(impl: MusicRepositoryImpl): MusicRepository

    @Binds
    @Singleton
    abstract fun bindNotificationRepository(impl: NotificationRepositoryImpl): NotificationRepository
}
