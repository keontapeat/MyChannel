import type { Meta, StoryObj } from '@storybook/react';
import Hero from './Hero';

const meta: Meta<typeof Hero> = {
  title: 'Layout/Hero',
  component: Hero,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Hero>;

export const Default: Story = {
  args: {
    title: 'Your Channel. Your Future.',
    subtitle: 'The next-generation video platform combining YouTube + Twitch + DraftKings + UFC.',
    ctaPrimary: {
      text: 'Get Started',
      href: '/signup',
    },
    ctaSecondary: {
      text: 'Watch Demo',
      href: '/watch/demo',
    },
  },
};

export const WithStats: Story = {
  args: {
    title: 'Your Channel. Your Future.',
    subtitle: 'The next-generation video platform combining YouTube + Twitch + DraftKings + UFC.',
    ctaPrimary: {
      text: 'Get Started',
      href: '/signup',
    },
    stats: [
      { label: 'Active Creators', value: '1M+', icon: null },
      { label: 'Daily Views', value: '50M+', icon: null },
      { label: 'Awards Given', value: '10K+', icon: null },
    ],
  },
};

export const WithFeaturedVideo: Story = {
  args: {
    title: 'Your Channel. Your Future.',
    subtitle: 'The next-generation video platform combining YouTube + Twitch + DraftKings + UFC.',
    ctaPrimary: {
      text: 'Get Started',
      href: '/signup',
    },
    featuredVideo: {
      id: 'demo',
      title: 'Shot By Keonta - Introduction',
      thumbnail: 'https://picsum.photos/1280/720',
      channel: 'MyChannel',
    },
  },
};

