import type { Meta, StoryObj } from '@storybook/react';
import Header from './Header';

const meta: Meta<typeof Header> = {
  title: 'Layout/Header',
  component: Header,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Header>;

export const Default: Story = {
  args: {
    onToggleSidebar: () => console.log('Toggle sidebar'),
  },
};

export const Authenticated: Story = {
  args: {
    onToggleSidebar: () => console.log('Toggle sidebar'),
  },
  decorators: [
    (Story) => (
      <div>
        <Story />
        {/* Mock authenticated state by modifying component internally */}
      </div>
    ),
  ],
};

export const Mobile: Story = {
  args: {
    onToggleSidebar: () => console.log('Toggle sidebar'),
  },
  parameters: {
    viewport: {
      defaultViewport: 'mobile1',
    },
  },
};



