import { ButtonHTMLAttributes, forwardRef } from 'react';
import { clsx } from 'clsx';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ variant = 'primary', size = 'md', className, children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={clsx(
          'inline-flex items-center justify-center rounded-full font-semibold transition-all duration-200 focus:outline-none focus:ring-4 focus:ring-offset-2',
          {
            'bg-[rgb(var(--color-primary))] text-white hover:bg-[rgb(var(--color-primary-hover))] focus:ring-[rgb(var(--color-primary))]':
              variant === 'primary',
            'bg-[rgb(var(--color-surface))] text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface-hover))] focus:ring-[rgb(var(--color-primary))]':
              variant === 'secondary',
            'border-2 border-[rgb(var(--color-border))] bg-transparent text-[rgb(var(--color-text-primary))] hover:bg-[rgb(var(--color-surface))] focus:ring-[rgb(var(--color-primary))]':
              variant === 'outline',
            'px-4 py-2 text-sm': size === 'sm',
            'px-6 py-3 text-base': size === 'md',
            'px-8 py-4 text-lg': size === 'lg',
          },
          className
        )}
        {...props}
      >
        {children}
      </button>
    );
  }
);

Button.displayName = 'Button';

export { Button };





