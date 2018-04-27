#ifndef POINTERDEQUE_HPP
#define POINTERDEQUE_HPP

	// This is a simple double ended queue template.  Any pointer-type can be stored in this deque
	// I pop/peek return NULL if the queue is empty.
template<typename T> class PointerDeque
{
	public:
		PointerDeque(int entriesPerPage);
		~PointerDeque();

		void PushLeft(T* obj);
		T* PopLeft();
		void PushRight(T* obj);
		T* PopRight();
		T* PeekLeft();
		T* PeekRight();
		T* Peek(int index);
		int Count();

	protected:
		void Expand();

		int mEntriesPerPage;
		T** mEntries;
		int mEntriesCount;
		int mEntriesMax;
		int mOffsetLeft;
};


template<typename T> PointerDeque<T>::PointerDeque(int entriesPerPage)
{
	mEntriesPerPage = entriesPerPage;
	mEntries = NULL;
	mOffsetLeft = 0;
	mEntriesMax = 0;
	mEntriesCount = 0;
}

template<typename T> PointerDeque<T>::~PointerDeque()
{
	delete[] mEntries;
}

template<typename T> void PointerDeque<T>::Expand()
{
	int countToEnd = (mEntriesMax - mOffsetLeft);
	mEntriesMax += mEntriesPerPage;
	T** newHold = new T*[mEntriesMax];

	if (countToEnd < mEntriesCount)
	{
		memcpy(newHold, &mEntries[mOffsetLeft], countToEnd * sizeof(T*));
		memcpy(newHold + countToEnd, mEntries, (mEntriesCount - countToEnd) * sizeof(T*));
	}
	else
		memcpy(newHold, &mEntries[mOffsetLeft], mEntriesCount * sizeof(T*));

	delete[] mEntries;
	mEntries = newHold;
	mOffsetLeft = 0;
}

template<typename T> void PointerDeque<T>::PushLeft(T* obj)
{
	if (mEntriesCount >= mEntriesMax)
		Expand();
	mEntries[(mOffsetLeft - 1 + mEntriesMax) % mEntriesMax] = obj;
	mEntriesCount++;
}

template<typename T> T* PointerDeque<T>::PopLeft()
{
	if (mEntriesCount == 0)
		return(NULL);
	T* hold = mEntries[mOffsetLeft];
	mOffsetLeft = (mOffsetLeft + 1) % mEntriesMax;
	mEntriesCount--;
	return(hold);
}

template<typename T> void PointerDeque<T>::PushRight(T* obj)
{
	if (mEntriesCount >= mEntriesMax)
		Expand();
	mEntries[(mOffsetLeft + mEntriesCount) % mEntriesMax] = obj;
	mEntriesCount++;
}

template<typename T> T* PointerDeque<T>::PopRight()
{
	if (mEntriesCount == 0)
		return(NULL);
	mEntriesCount--;
	return(mEntries[(mOffsetLeft + mEntriesCount) % mEntriesMax]);
}

template<typename T> T* PointerDeque<T>::PeekLeft()
{
	if (mEntriesCount == 0)
		return(NULL);
	return(mEntries[mOffsetLeft]);
}

template<typename T> T* PointerDeque<T>::PeekRight()
{
	if (mEntriesCount == 0)
		return(NULL);
	return(mEntries[(mOffsetLeft + mEntriesCount - 1) % mEntriesMax]);
}

template<typename T> T* PointerDeque<T>::Peek(int index)
{
	if (index >= mEntriesCount)
		return(NULL);
	return(mEntries[(mOffsetLeft + index) % mEntriesMax]);
}

template<typename T> int PointerDeque<T>::Count()
{
	return(mEntriesCount);
}

#endif

