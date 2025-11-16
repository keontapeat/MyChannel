import type { Meta, StoryObj } from '@storybook/react';
import VideoCard from './VideoCard';

const meta: Meta<typeof VideoCard> = {
  title: 'Video/VideoCard',
  component: VideoCard,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof VideoCard>;

const sampleVideo = {
  id: '1',
  title: 'Amazing Video Title - This is a longer title to test truncation',
  thumbnailURL: 'https://picsum.photos/640/360',
  duration: '10:30',
  channel: 'Creator Name',
  channelIcon: 'https://i.pravatar.cc/150?img=1',
  views: '1.2M',
  timeAgo: '2 days ago',
  isVerified: true,
};

export const Default: Story = {
  args: {
    video: sampleVideo,
  },
};

export const LongTitle: Story = {
  args: {
    video: {
      ...sampleVideo,
      title: 'This is an extremely long video title that should truncate properly with ellipsis when it exceeds two lines',
    },
  },
};

export const Unverified: Story = {
  args: {
    video: {
      ...sampleVideo,
      isVerified: false,
    },
  },
};

export const Grid: Story = {
  args: {
    video: sampleVideo,
  },
  decorators: [
    (Story) => (
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 p-4">
        <Story />
        <Story />
        <Story />
        <Story />
      </div>
    ),
  ],
};

