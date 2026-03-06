import React from 'react'
import { Metric } from '../../../types/query-api'
import { numberShortFormatter } from '../../util/number-formatter'
import { ArrowDownRightIcon, ArrowUpRightIcon } from '@heroicons/react/24/solid'
import classNames from 'classnames'

export function ChangeArrow({
  change,
  metric,
  className,
  hideNumber,
  absoluteChange
}: {
  change: number
  metric: Metric
  className: string
  hideNumber?: boolean
  absoluteChange?: number
}) {
  let formattedChange = null
  if (!hideNumber) {
    if (absoluteChange !== undefined) {
      const sign = absoluteChange > 0 ? '+' : ''
      formattedChange = ` ${sign}${numberShortFormatter(Math.abs(absoluteChange))}${absoluteChange < 0 ? '' : ''}`
      formattedChange = ` ${absoluteChange > 0 ? '+' : '-'}${numberShortFormatter(Math.abs(absoluteChange))}`
    } else {
      formattedChange = ` ${numberShortFormatter(Math.abs(change))}%`
    }
  }

  let icon = null
  const arrowClassName = classNames(
    color(change, metric),
    'inline-block h-3 w-3 stroke-[1px] stroke-current'
  )

  if (change > 0) {
    icon = <ArrowUpRightIcon className={arrowClassName} />
  } else if (change < 0) {
    icon = <ArrowDownRightIcon className={arrowClassName} />
  } else if (change === 0 && !hideNumber) {
    icon = <>&#12336;</>
  }

  return (
    <span className={className} data-testid="change-arrow">
      {icon}
      {formattedChange}
    </span>
  )
}

function color(change: number, metric: Metric) {
  const invert = metric === 'bounce_rate'

  return change > 0 != invert ? 'text-green-500' : 'text-red-400'
}
