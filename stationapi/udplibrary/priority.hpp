#ifndef PRIORITY_HPP
#define PRIORITY_HPP


template<typename T, typename P> class PriorityQueue;

	// classes that wish to be members of the priority queue below must derive themselves from this class
	// in order to pull in the two member variables.  Unlike normal priority queue classes which don't
	// have this restriction, it is required in order to support Remove and reprioritize functionality
	// in a timely manner (otherwise, in order to remove an entry that is not at the top, you would have
	// to linearly scan the entire queue).  This is accomplished by having the member itself contain
	// a pointer to it's position in the queue (mPriorityQueuePosition).
	// note: a restriction of this ability is that an object cannot participate in more than one priority
	// queue at a time.
class PriorityQueueMember
{
	public:
		PriorityQueueMember();

#if defined(_MSC_VER) && (_MSC_VER >= 1300)		// MSVC 7.0 is the first version to support friend templates
		template<typename T, typename P> friend class PriorityQueue;
	protected:
#else
	public:
#endif
		int mPriorityQueuePosition;		// -1=not in queue
};

	// this class provides a priority queue that is capable of reprioritizing/removing entries.  The
	// compiler will ensure that objects stored in this class are derived from PriorityQueueMember.
	// We don't really need this to be a template class, since we could just treat everything as a
	// PriorityQueueMember, but then the application would lose some type checking.  We don't use references
	// in the api as most priority queue templates do as we can't support non pointer types anyways.
template<typename T, typename P> class PriorityQueue
{
	public:
		PriorityQueue(int queueSize);
		~PriorityQueue();

		T* Top();							// returns NULL if queue is empty
		T* TopRemove();						// returns NULL if queue is empty
		T* TopRemove(P priority);			// removes item from queue if it has a lower priority value, otherwise return NULL
		T* Add(T* entry, P priority);		// reprioritizes if already in queue, returns entry always
		T* Remove(T* entry);				// returns entry always (even if it was not in the queue)
		P *GetPriority(T* entry);			// returns NULL if entry is not in the queue
		int QueueUsed();					// returns how many entries are in the queue
	protected:
		struct QueueEntry
		{
			T* entry;
			P priority;
		};

		QueueEntry* mQueue;
		int mQueueSize;
		int mQueueEnd;

		void Refloat(T* entry);
};



	//////////////////////////////////////////////////////////////////////////
	// PriorityQueueMember implementation
	//////////////////////////////////////////////////////////////////////////
inline PriorityQueueMember::PriorityQueueMember()
{
	mPriorityQueuePosition = -1;
}


	//////////////////////////////////////////////////////////////////////////
	// PriorityQueue implementation
	//////////////////////////////////////////////////////////////////////////
template<typename T, typename P> PriorityQueue<T, P>::PriorityQueue(int queueSize)
{
	mQueueEnd = 0;
	mQueueSize = queueSize;
	mQueue = new QueueEntry[mQueueSize];
	memset(mQueue, 0, mQueueSize);
}

template<typename T, typename P> PriorityQueue<T, P>::~PriorityQueue()
{
	delete[] mQueue;
}

template<typename T, typename P> T* PriorityQueue<T, P>::Top()
{
	if (mQueueEnd == 0)
		return(NULL);
	return(mQueue[0].entry);
}

template<typename T, typename P> T* PriorityQueue<T, P>::TopRemove()
{
	if (mQueueEnd == 0)
		return(NULL);
	T* top = mQueue[0].entry;
	Remove(top);
	return(top);
}

template<typename T, typename P> T* PriorityQueue<T, P>::TopRemove(P priority)
{
	if (mQueueEnd > 0 && mQueue[0].priority <= priority)
		return(Remove(mQueue[0].entry));
	return(NULL);
}

template<typename T, typename P> P* PriorityQueue<T, P>::GetPriority(T* entry)
{
	if (entry->mPriorityQueuePosition >= 0)
		return(&mQueue[entry->mPriorityQueuePosition].priority);
	return(NULL);
}

template<typename T, typename P> T* PriorityQueue<T, P>::Add(T* entry, P priority)
{
	if (entry->mPriorityQueuePosition == -1)
	{
			// not in queue, so add it to the bottom
		if (mQueueEnd >= mQueueSize)
			return(NULL);
		mQueue[mQueueEnd].entry = entry;
		mQueue[mQueueEnd].priority = priority;
		mQueue[mQueueEnd].entry->mPriorityQueuePosition = mQueueEnd;
		mQueueEnd++;
	}
	else
	{
			// see if priority has actually changed, if not, just return, otherwise change priority and fall through to refloat it
		if (mQueue[entry->mPriorityQueuePosition].priority == priority)
			return(entry);
		mQueue[entry->mPriorityQueuePosition].priority = priority;
	}

	Refloat(entry);
	return(entry);
}

template<typename T, typename P> T* PriorityQueue<T, P>::Remove(T* entry)
{
	if (entry->mPriorityQueuePosition == -1)
		return(entry);

		// move end entry into place of one being removed
	mQueueEnd--;
	int spot = entry->mPriorityQueuePosition;
	if (spot != mQueueEnd)		// don't remove last item in queue (bottom of tree), so no need to copy bottom one up and refloat it (we would be refloating our own removed entry)
	{
		mQueue[spot] = mQueue[mQueueEnd];
		mQueue[spot].entry->mPriorityQueuePosition = spot;
		Refloat(mQueue[spot].entry);
	}
	entry->mPriorityQueuePosition = -1;
	return(entry);
}

template<typename T, typename P> void PriorityQueue<T, P>::Refloat(T* entry)
{
		// float upward
	int spot = entry->mPriorityQueuePosition;
	bool tryDown = true;
	while (spot > 0 && mQueue[spot].priority < mQueue[(spot - 1) / 2].priority)
	{
		int newSpot = (spot - 1) / 2;
		QueueEntry hold = mQueue[spot];
		mQueue[spot] = mQueue[newSpot];
		mQueue[newSpot] = hold;
		mQueue[spot].entry->mPriorityQueuePosition = spot;
		mQueue[newSpot].entry->mPriorityQueuePosition = newSpot;
		spot = newSpot;
		tryDown = false;
	}

	if (tryDown)
	{
			// if we didn't manage to float up at all, then we need to try floating down
		for (;;)
		{
				// pick smallest child
			int downSpot1 = (spot * 2) + 1;
			if (downSpot1 >= mQueueEnd)
				break;
			int downSpot2 = (spot * 2) + 2;

			if (downSpot2 >= mQueueEnd || mQueue[downSpot1].priority < mQueue[downSpot2].priority)
			{
				if (mQueue[downSpot1].priority < mQueue[spot].priority)
				{
					QueueEntry hold = mQueue[spot];
					mQueue[spot] = mQueue[downSpot1];
					mQueue[downSpot1] = hold;
					mQueue[spot].entry->mPriorityQueuePosition = spot;
					mQueue[downSpot1].entry->mPriorityQueuePosition = downSpot1;
					spot = downSpot1;
				}
				else
					break;
			}
			else
			{
				if (mQueue[downSpot2].priority < mQueue[spot].priority)
				{
					QueueEntry hold = mQueue[spot];
					mQueue[spot] = mQueue[downSpot2];
					mQueue[downSpot2] = hold;
					mQueue[spot].entry->mPriorityQueuePosition = spot;
					mQueue[downSpot2].entry->mPriorityQueuePosition = downSpot2;
					spot = downSpot2;
				}
				else
					break;
			}
		}
	}
}

template<typename T, typename P> int PriorityQueue<T, P>::QueueUsed()
{
	return(mQueueEnd);
}

#endif
